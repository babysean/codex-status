import Foundation

struct RateLimitsReadResult: Decodable, Sendable {
    let rateLimits: RateLimitsPayload?
    let rateLimitsByLimitID: [String: RateLimitsPayload]
    let rateLimitResetCredits: RateLimitResetCreditsPayload?

    enum CodingKeys: String, CodingKey {
        case rateLimits
        case rateLimitsByLimitID = "rateLimitsByLimitId"
        case rateLimitResetCredits
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rateLimits = values.decodeSafely(RateLimitsPayload.self, forKey: .rateLimits)
        rateLimitsByLimitID = values.decodeSafely([String: RateLimitsPayload].self, forKey: .rateLimitsByLimitID) ?? [:]
        rateLimitResetCredits = values.decodeSafely(RateLimitResetCreditsPayload.self, forKey: .rateLimitResetCredits)
    }

    /// Stable ordering keeps UI updates from reshuffling rows. The legacy object
    /// is preferred for metadata and is emitted first; dictionary buckets follow
    /// in key order. A shared limit id is represented only once.
    var orderedLimits: [RateLimitsEntry] {
        var entries: [RateLimitsEntry] = []
        var seenLimitIDs = Set<String>()

        func append(_ payload: RateLimitsPayload, fallbackID: String?) {
            let id = payload.limitID == "default" ? (fallbackID ?? payload.limitID) : payload.limitID
            guard seenLimitIDs.insert(id).inserted else { return }
            entries.append(RateLimitsEntry(limitID: id, payload: payload))
        }

        if let rateLimits {
            append(rateLimits, fallbackID: nil)
        }
        for key in rateLimitsByLimitID.keys.sorted() {
            guard let payload = rateLimitsByLimitID[key] else { continue }
            append(payload, fallbackID: key)
        }
        return entries
    }
}

struct RateLimitResetCreditsPayload: Decodable, Sendable {
    let availableCount: Int

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: DynamicCodingKey.self)
        availableCount = max(values.decodeInt(forKey: DynamicCodingKey("availableCount")) ?? 0, 0)
    }
}

struct ConsumeRateLimitResetCreditParams: Encodable, Sendable {
    let idempotencyKey: String
}

struct ConsumeRateLimitResetCreditResult: Decodable, Sendable {
    let outcome: UsageLimitResetOutcome
}

struct RateLimitsEntry: Sendable {
    let limitID: String
    let payload: RateLimitsPayload
}

struct RateLimitsPayload: Decodable, Sendable {
    let limitID: String
    let limitName: String?
    let primary: RateLimitWindowPayload?
    let secondary: RateLimitWindowPayload?
    let individualLimit: SpendControlLimitPayload?
    let credits: CreditsPayload?
    let spendControlReached: Bool
    let planType: String?
    let rateLimitReachedType: String?

    enum CodingKeys: String, CodingKey {
        case limitID = "limitId"
        case limitName, primary, secondary, individualLimit, credits, spendControlReached, planType, rateLimitReachedType
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        limitID = values.decodeString(forKey: .limitID) ?? "default"
        limitName = values.decodeString(forKey: .limitName)
        primary = values.decodeSafely(RateLimitWindowPayload.self, forKey: .primary)
        secondary = values.decodeSafely(RateLimitWindowPayload.self, forKey: .secondary)
        individualLimit = values.decodeSafely(SpendControlLimitPayload.self, forKey: .individualLimit)
        credits = values.decodeSafely(CreditsPayload.self, forKey: .credits)
        spendControlReached = values.decodeBool(forKey: .spendControlReached) ?? false
        planType = values.decodeString(forKey: .planType)
        rateLimitReachedType = values.decodeString(forKey: .rateLimitReachedType)
    }
}

/// `individualLimit` is a spend-control snapshot, not a rate-limit window.
/// The protocol has exposed both `remainingPercent` and `limit`/`used` across
/// versions, so retain both representations and derive use at the mapper edge.
struct SpendControlLimitPayload: Decodable, Sendable {
    let limit: Double?
    let used: Double?
    let remainingPercent: Double?
    let resetsAt: Double?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: DynamicCodingKey.self)
        limit = values.decodeDouble(forKey: DynamicCodingKey("limit"))
        used = values.decodeDouble(forKey: DynamicCodingKey("used"))
        remainingPercent = values.decodeDouble(forKey: DynamicCodingKey("remainingPercent"))
        resetsAt = values.decodeDouble(forKey: DynamicCodingKey("resetsAt"))
    }

    var usedPercent: Double? {
        if let remainingPercent {
            return 100 - remainingPercent
        }
        guard let limit, limit > 0, let used else { return nil }
        return used / limit * 100
    }
}

struct RateLimitWindowPayload: Decodable, Sendable {
    let usedPercent: Double?
    let windowDurationMins: Int?
    let resetsAt: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent, windowDurationMins, resetsAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = values.decodeDouble(forKey: .usedPercent)
        windowDurationMins = values.decodeInt(forKey: .windowDurationMins)
        resetsAt = values.decodeDouble(forKey: .resetsAt)
    }
}

struct CreditsPayload: Decodable, Sendable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: Double?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: DynamicCodingKey.self)
        hasCredits = values.decodeBool(forKey: DynamicCodingKey("hasCredits"))
        unlimited = values.decodeBool(forKey: DynamicCodingKey("unlimited"))
        balance = values.decodeDouble(forKey: DynamicCodingKey("balance"))
    }
}

struct UsageReadResult: Decodable, Sendable {
    let summary: UsageSummaryPayload?
    let dailyUsageBuckets: [DailyUsageBucketPayload]

    enum CodingKeys: String, CodingKey {
        case summary, dailyUsageBuckets
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        summary = values.decodeSafely(UsageSummaryPayload.self, forKey: .summary)
        dailyUsageBuckets = values.decodeSafely([DailyUsageBucketPayload].self, forKey: .dailyUsageBuckets) ?? []
    }
}

struct UsageSummaryPayload: Decodable, Sendable {
    let lifetimeTokens: Int?
    let peakDailyTokens: Int?
    let longestRunningTurnSec: Int?
    let currentStreakDays: Int?
    let longestStreakDays: Int?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: DynamicCodingKey.self)
        lifetimeTokens = values.decodeInt(forKey: DynamicCodingKey("lifetimeTokens"))
        peakDailyTokens = values.decodeInt(forKey: DynamicCodingKey("peakDailyTokens"))
        longestRunningTurnSec = values.decodeInt(forKey: DynamicCodingKey("longestRunningTurnSec"))
        currentStreakDays = values.decodeInt(forKey: DynamicCodingKey("currentStreakDays"))
        longestStreakDays = values.decodeInt(forKey: DynamicCodingKey("longestStreakDays"))
    }
}

struct DailyUsageBucketPayload: Decodable, Sendable {
    let startDate: String?
    let tokens: Int?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: DynamicCodingKey.self)
        startDate = values.decodeString(forKey: DynamicCodingKey("startDate"))
        tokens = values.decodeInt(forKey: DynamicCodingKey("tokens"))
    }
}

struct DynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) { self.init(stringValue) }
    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer {
    func decodeSafely<Value: Decodable>(_ type: Value.Type, forKey key: Key) -> Value? {
        try? decodeIfPresent(type, forKey: key)
    }

    func decodeString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return "\(value)" }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return "\(value)" }
        return nil
    }

    func decodeDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }

    func decodeInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key), let parsed = Int(value) { return parsed }
        return nil
    }

    func decodeBool(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "1": return true
            case "false", "0": return false
            default: return nil
            }
        }
        return nil
    }
}
