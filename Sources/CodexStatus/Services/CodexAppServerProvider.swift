import Foundation

actor CodexAppServerProvider: UsageProvider {
    private let client: AppServerClient

    init(client: AppServerClient = AppServerClient()) {
        self.client = client
    }

    func fetchUsage() async throws -> UsageSnapshot {
        try await client.connectIfNeeded()
        let limits = try await client.readRateLimits()

        // Token usage is supplementary. A server version that does not expose it
        // must not prevent the menu bar's core limit status from being shown.
        let usage = try? await client.readUsage()
        return UsageSnapshotMapper.snapshot(limits: limits, usage: usage, fetchedAt: Date())
    }

    func shutdown() async {
        await client.shutdown()
    }

    func resetUsageLimit() async throws -> UsageLimitResetOutcome {
        try await client.consumeRateLimitResetCredit()
    }
}
