import Foundation

enum AppServerClientError: LocalizedError, Sendable, Equatable {
    case executableNotFound
    case launchFailed(String)
    case connectionClosed(String)
    case timedOut(String)
    case rpc(code: Int, message: String)
    case invalidResponse(details: String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Codex CLI executable was not found."
        case let .launchFailed(details), let .connectionClosed(details), let .timedOut(details), let .invalidResponse(details):
            return details
        case let .rpc(code, message):
            return "Codex app-server error \(code): \(message)"
        }
    }
}

struct CodexExecutableLocator: Sendable {
    private static let fixedCandidates = [
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex",
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex"
    ]

    func locate(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        var candidates = Self.fixedCandidates
        if let path = environment["PATH"] {
            candidates.append(contentsOf: path.split(separator: ":").compactMap { entry in
                guard entry.hasPrefix("/") else { return nil }
                return "\(entry)/codex"
            })
        }

        var seen = Set<String>()
        for path in candidates where seen.insert(path).inserted {
            let url = URL(fileURLWithPath: path)
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  FileManager.default.isExecutableFile(atPath: url.path)
            else {
                continue
            }
            return url
        }
        return nil
    }
}

/// JSON-RPC client for a child `codex app-server --stdio` process.
/// It intentionally talks to the executable directly: no shell is involved.
actor AppServerClient {
    private let executableLocator: CodexExecutableLocator
    private var process: Process?
    private var input: Pipe?
    private var output: Pipe?
    private var outputBuffer = Data()
    private var nextRequestID = 1
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var initialized = false
    private var activeProcessID: UUID?

    init(executableLocator: CodexExecutableLocator = CodexExecutableLocator()) {
        self.executableLocator = executableLocator
    }

    func connectIfNeeded() async throws {
        if initialized, process?.isRunning == true {
            return
        }

        if process != nil {
            shutdown()
        }

        guard let executableURL = executableLocator.locate() else {
            throw AppServerClientError.executableNotFound
        }

        let input = Pipe()
        let output = Pipe()
        let process = Process()
        let processID = UUID()
        process.executableURL = executableURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            Task { await self?.receiveOutput(data, processID: processID) }
        }
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            Task { await self?.processDidTerminate(status: status, processID: processID) }
        }

        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            throw AppServerClientError.launchFailed(error.localizedDescription)
        }

        self.process = process
        self.input = input
        self.output = output
        self.initialized = false
        self.activeProcessID = processID

        do {
            let initialization = InitializeParams(
                clientInfo: .init(name: "codex-status", title: "Codex Status", version: "0.1.0")
            )
            _ = try await requestData(method: "initialize", params: initialization)
            try sendNotification(method: "initialized", params: EmptyParams())
            initialized = true
        } catch {
            shutdown()
            throw error
        }
    }

    func readRateLimits() async throws -> RateLimitsReadResult {
        try await connectIfNeeded()
        return try await request(method: "account/rateLimits/read", params: EmptyParams())
    }

    func readUsage() async throws -> UsageReadResult {
        try await connectIfNeeded()
        return try await request(method: "account/usage/read", params: EmptyParams())
    }

    func consumeRateLimitResetCredit() async throws -> UsageLimitResetOutcome {
        try await connectIfNeeded()
        let params = ConsumeRateLimitResetCreditParams(idempotencyKey: UUID().uuidString)
        let result: ConsumeRateLimitResetCreditResult = try await request(
            method: "account/rateLimitResetCredit/consume",
            params: params
        )
        return result.outcome
    }

    func shutdown() {
        initialized = false
        activeProcessID = nil

        let error = AppServerClientError.connectionClosed("Codex app-server connection closed.")
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }

        output?.fileHandleForReading.readabilityHandler = nil
        input?.fileHandleForWriting.closeFile()
        if let process, process.isRunning {
            process.terminate()
        }
        input = nil
        output = nil
        process = nil
        outputBuffer.removeAll(keepingCapacity: false)
    }

    private func request<Response: Decodable, Parameters: Encodable>(
        method: String,
        params: Parameters
    ) async throws -> Response {
        let data = try await requestData(method: method, params: params)
        let envelope: JSONRPCResponse<Response>
        do {
            envelope = try JSONDecoder().decode(JSONRPCResponse<Response>.self, from: data)
        } catch {
            throw AppServerClientError.invalidResponse(details: "Could not decode \(method) response: \(error.localizedDescription)")
        }

        if let error = envelope.error {
            throw AppServerClientError.rpc(code: error.code, message: error.message)
        }
        guard let result = envelope.result else {
            throw AppServerClientError.invalidResponse(details: "Codex returned no result for \(method).")
        }
        return result
    }

    private func requestData<Parameters: Encodable>(method: String, params: Parameters) async throws -> Data {
        guard process?.isRunning == true, let input else {
            throw AppServerClientError.connectionClosed("Codex app-server is not running.")
        }

        let requestID = nextRequestID
        nextRequestID += 1
        let request = JSONRPCRequest(id: requestID, method: method, params: params)
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(request) + Data([0x0A])
        } catch {
            throw AppServerClientError.invalidResponse(details: "Could not encode \(method) request: \(error.localizedDescription)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            pending[requestID] = continuation
            do {
                try input.fileHandleForWriting.write(contentsOf: encoded)
            } catch {
                pending.removeValue(forKey: requestID)?.resume(
                    throwing: AppServerClientError.connectionClosed("Could not write to Codex app-server: \(error.localizedDescription)")
                )
                return
            }

            Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(15))
                } catch {
                    return
                }
                await self?.timeout(requestID: requestID, method: method)
            }
        }
    }

    private func sendNotification<Parameters: Encodable>(method: String, params: Parameters) throws {
        guard process?.isRunning == true, let input else {
            throw AppServerClientError.connectionClosed("Codex app-server is not running.")
        }
        let notification = JSONRPCNotification(method: method, params: params)
        do {
            try input.fileHandleForWriting.write(contentsOf: try JSONEncoder().encode(notification) + Data([0x0A]))
        } catch {
            throw AppServerClientError.connectionClosed("Could not write to Codex app-server: \(error.localizedDescription)")
        }
    }

    private func receiveOutput(_ data: Data, processID: UUID) {
        guard activeProcessID == processID else { return }
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = Data(outputBuffer[..<newline])
            outputBuffer.removeSubrange(...newline)
            resumeRequest(for: line)
        }
    }

    private func resumeRequest(for line: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let requestID = object["id"] as? NSNumber
        else {
            return // JSON-RPC notifications and diagnostics do not have a request id.
        }
        pending.removeValue(forKey: requestID.intValue)?.resume(returning: line)
    }

    private func timeout(requestID: Int, method: String) {
        pending.removeValue(forKey: requestID)?.resume(
            throwing: AppServerClientError.timedOut("Timed out waiting for \(method).")
        )
    }

    private func processDidTerminate(status: Int32, processID: UUID) {
        guard activeProcessID == processID else { return }
        initialized = false
        activeProcessID = nil
        let error = AppServerClientError.connectionClosed("Codex app-server exited with status \(status).")
        let continuations = pending.values
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: error) }
        output?.fileHandleForReading.readabilityHandler = nil
        input?.fileHandleForWriting.closeFile()
        input = nil
        output = nil
        process = nil
        outputBuffer.removeAll(keepingCapacity: false)
    }
}

private struct EmptyParams: Codable {}

private struct InitializeParams: Encodable {
    let clientInfo: ClientInfo

    struct ClientInfo: Encodable {
        let name: String
        let title: String
        let version: String
    }
}

private struct JSONRPCRequest<Parameters: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let id: Int
    let method: String
    let params: Parameters
}

private struct JSONRPCNotification<Parameters: Encodable>: Encodable {
    let jsonrpc = "2.0"
    let method: String
    let params: Parameters
}

private struct JSONRPCResponse<Result: Decodable>: Decodable {
    let result: Result?
    let error: JSONRPCError?
}

private struct JSONRPCError: Decodable {
    let code: Int
    let message: String
}
