import Foundation

protocol UsageProvider: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
    func resetUsageLimit() async throws -> UsageLimitResetOutcome
    func shutdown() async
}

extension UsageProvider {
    func resetUsageLimit() async throws -> UsageLimitResetOutcome {
        throw AppServerClientError.invalidResponse(details: "이 Codex 버전은 사용한도 초기화를 지원하지 않습니다.")
    }

    func shutdown() async {}
}
