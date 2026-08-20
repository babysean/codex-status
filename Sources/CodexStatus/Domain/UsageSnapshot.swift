import Foundation

struct UsageSnapshot: Sendable, Equatable {
    let windows: [UsageWindow]
    let credits: CreditStatus?
    let resetCreditsAvailable: Int
    let planName: String?
    let tokenSummary: TokenSummary?
    let fetchedAt: Date

    /// The window that should be shown in the menu bar.
    /// Reached limits take precedence; otherwise the most-used limit wins.
    var representativeWindow: UsageWindow? {
        let reached = windows.filter(\.isLimitReached)
        if let highestReached = reached.max(by: { $0.usedPercent < $1.usedPercent }) {
            return highestReached
        }

        if let highestUsage = windows.max(by: { $0.usedPercent < $1.usedPercent }) {
            return highestUsage
        }

        return windows.first(where: \.isPrimary)
    }
}

struct UsageWindow: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let usedPercent: Double
    let durationMinutes: Int?
    let resetsAt: Date?
    let isPrimary: Bool
    let isLimitReached: Bool

    init(
        id: String,
        name: String,
        usedPercent: Double,
        durationMinutes: Int? = nil,
        resetsAt: Date? = nil,
        isPrimary: Bool = false,
        isLimitReached: Bool = false
    ) {
        self.id = id
        self.name = name
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.durationMinutes = durationMinutes
        self.resetsAt = resetsAt
        self.isPrimary = isPrimary
        self.isLimitReached = isLimitReached
    }
}

struct CreditStatus: Sendable, Equatable {
    let hasCredits: Bool
    let isUnlimited: Bool
    let balance: Double?
}

enum UsageLimitResetOutcome: String, Codable, Sendable, Equatable {
    case reset
    case nothingToReset
    case noCredit
    case alreadyRedeemed
}

struct TokenSummary: Sendable, Equatable {
    let lifetimeTokens: Int?
    let peakDailyTokens: Int?
    let longestRunningTurnSeconds: Int?
    let currentStreakDays: Int?
    let longestStreakDays: Int?
}
