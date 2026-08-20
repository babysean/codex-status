import Foundation

enum UsageSnapshotMapper {
    static func snapshot(
        limits result: RateLimitsReadResult,
        usage: UsageReadResult?,
        fetchedAt: Date
    ) -> UsageSnapshot {
        let entries = result.orderedLimits
        let windows = entries.flatMap { makeWindows(for: $0) }
        let representative = result.rateLimits ?? entries.first?.payload

        let credits = (result.rateLimits?.credits ?? entries.compactMap(\.payload.credits).first).map {
            CreditStatus(
                hasCredits: $0.hasCredits ?? false,
                isUnlimited: $0.unlimited ?? false,
                balance: $0.balance
            )
        }
        let tokenSummary = usage?.summary.map {
            TokenSummary(
                lifetimeTokens: $0.lifetimeTokens,
                peakDailyTokens: $0.peakDailyTokens,
                longestRunningTurnSeconds: $0.longestRunningTurnSec,
                currentStreakDays: $0.currentStreakDays,
                longestStreakDays: $0.longestStreakDays
            )
        }

        return UsageSnapshot(
            windows: windows,
            credits: credits,
            resetCreditsAvailable: result.rateLimitResetCredits?.availableCount ?? 0,
            planName: result.rateLimits?.planType ?? entries.compactMap(\.payload.planType).first ?? representative?.planType,
            tokenSummary: tokenSummary,
            fetchedAt: fetchedAt
        )
    }

    private static func makeWindows(for entry: RateLimitsEntry) -> [UsageWindow] {
        let limits = entry.payload
        let reachedType = limits.rateLimitReachedType?.lowercased()
        let globallyReached = isGlobalRateLimitReached(reachedType)
        return [
            makeWindow(
                payload: limits.primary,
                id: "\(entry.limitID).primary",
                name: limits.limitName ?? defaultName(for: limits.primary, fallback: "단기 한도"),
                isPrimary: true,
                isReached: globallyReached || reachedType == "primary"
            ),
            makeWindow(
                payload: limits.secondary,
                id: "\(entry.limitID).secondary",
                name: defaultName(for: limits.secondary, fallback: "장기 한도"),
                isPrimary: false,
                isReached: globallyReached || reachedType == "secondary"
            ),
            makeIndividualWindow(
                payload: limits.individualLimit,
                id: "\(entry.limitID).individual",
                isReached: limits.spendControlReached || reachedType == "individual"
            )
        ].compactMap { $0 }
    }

    private static func isGlobalRateLimitReached(_ type: String?) -> Bool {
        guard let type else { return false }
        if type == "rate_limit_reached" { return true }
        return type.hasPrefix("workspace_") &&
            (type.contains("depleted") || type.contains("usage_limit_reached"))
    }

    private static func makeWindow(
        payload: RateLimitWindowPayload?,
        id: String,
        name: String,
        isPrimary: Bool,
        isReached: Bool
    ) -> UsageWindow? {
        guard let payload, let usedPercent = payload.usedPercent else { return nil }
        let resetsAt = payload.resetsAt.map { Date(timeIntervalSince1970: $0) }
        return UsageWindow(
            id: id,
            name: name,
            usedPercent: usedPercent,
            durationMinutes: payload.windowDurationMins,
            resetsAt: resetsAt,
            isPrimary: isPrimary,
            isLimitReached: isReached || usedPercent >= 100
        )
    }

    private static func makeIndividualWindow(
        payload: SpendControlLimitPayload?,
        id: String,
        isReached: Bool
    ) -> UsageWindow? {
        guard let payload, let usedPercent = payload.usedPercent else { return nil }
        return UsageWindow(
            id: id,
            name: "개별 한도",
            usedPercent: usedPercent,
            durationMinutes: nil,
            resetsAt: payload.resetsAt.map { Date(timeIntervalSince1970: $0) },
            isLimitReached: isReached || usedPercent >= 100
        )
    }

    private static func defaultName(for payload: RateLimitWindowPayload?, fallback: String) -> String {
        guard let minutes = payload?.windowDurationMins, minutes > 0 else { return fallback }
        if minutes % (24 * 60) == 0 {
            return "\(minutes / (24 * 60))일 한도"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60)시간 한도"
        }
        return "\(minutes)분 한도"
    }
}
