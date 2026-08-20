import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var connectionState: ConnectionState = .loading
    @Published private(set) var isRefreshing = false

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
