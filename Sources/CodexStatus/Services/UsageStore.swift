import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var connectionState: ConnectionState = .loading
    @Published private(set) var isRefreshing = false
    @Published private(set) var isResetting = false
    @Published var resetResultMessage: String?

    private let provider: any UsageProvider
    private let refreshInterval: Duration
    private var refreshTask: Task<Void, Never>?

    init(
        provider: any UsageProvider = CodexAppServerProvider(),
        refreshInterval: Duration = .seconds(60)
    ) {
        self.provider = provider
        self.refreshInterval = refreshInterval
    }

    func start() {
        guard refreshTask == nil else { return }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            await refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: refreshInterval)
                } catch {
                    return
                }
                await refresh()
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        if snapshot == nil {
            connectionState = .loading
        }
        defer { isRefreshing = false }

        do {
            snapshot = try await provider.fetchUsage()
            connectionState = .connected
        } catch {
            connectionState = state(for: error)
        }
    }

    var canResetUsageLimit: Bool {
        (snapshot?.resetCreditsAvailable ?? 0) > 0 && !isRefreshing && !isResetting
    }

    func resetUsageLimit() async {
        guard canResetUsageLimit else { return }
        isResetting = true
        defer { isResetting = false }

        do {
            let outcome = try await provider.resetUsageLimit()
            switch outcome {
            case .reset:
                resetResultMessage = "사용한도를 초기화했습니다."
            case .nothingToReset:
                resetResultMessage = "현재 초기화할 수 있는 사용한도가 없습니다."
            case .noCredit:
                resetResultMessage = "사용 가능한 초기화 크레딧이 없습니다."
            case .alreadyRedeemed:
                resetResultMessage = "이미 사용된 초기화 요청입니다."
            }
            await refresh()
        } catch {
            resetResultMessage = "사용한도를 초기화하지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func state(for error: Error) -> ConnectionState {
        if snapshot != nil, let lastSuccess = snapshot?.fetchedAt {
            return .stale(lastSuccess: lastSuccess)
        }

        guard let error = error as? AppServerClientError else {
            return .failed(details: error.localizedDescription)
        }

        switch error {
        case .executableNotFound:
            return .codexNotFound
        case let .rpc(code, message):
            let diagnostic = "\(code): \(message)"
            if code == 401 || message.localizedCaseInsensitiveContains("auth") || message.localizedCaseInsensitiveContains("login") {
                return .unauthenticated
            }
            return .failed(details: diagnostic)
        case let .invalidResponse(details):
            return .incompatibleProtocol(details: details)
        case let .launchFailed(details), let .connectionClosed(details), let .timedOut(details):
            return .failed(details: details)
        }
    }

    deinit {
        refreshTask?.cancel()
        let provider = provider
        Task { await provider.shutdown() }
    }
}
