import Foundation
import XCTest
@testable import CodexStatus

final class UsageSnapshotTests: XCTestCase {
    func testRepresentativeWindowPrefersReachedLimit() {
        let primary = UsageWindow(id: "primary", name: "Primary", usedPercent: 90, isPrimary: true)
        let reached = UsageWindow(id: "secondary", name: "Secondary", usedPercent: 75, isLimitReached: true)
        let snapshot = UsageSnapshot(
            windows: [primary, reached],
            credits: nil,
            planName: nil,
            tokenSummary: nil,
            fetchedAt: .now
        )

        XCTAssertEqual(snapshot.representativeWindow?.id, "secondary")
    }

    func testUsageWindowClampsInvalidPercentageAtBoundary() {
        XCTAssertEqual(UsageWindow(id: "low", name: "Low", usedPercent: -1).usedPercent, 0)
        XCTAssertEqual(UsageWindow(id: "high", name: "High", usedPercent: 102).usedPercent, 100)
    }

    func testRateLimitMappingAcceptsNumericStringsAndKeepsOptionalUsage() throws {
        let data = try XCTUnwrap(
            """
            {
              "rateLimits": {
                "limitId": "account",
                "limitName": "5시간 한도",
                "primary": { "usedPercent": "42.5", "windowDurationMins": "300", "resetsAt": "1800000000" },
                "secondary": { "usedPercent": 18, "windowDurationMins": 10080, "resetsAt": 1800100000 },
                "credits": { "hasCredits": "true", "unlimited": false, "balance": "12.75" },
                "planType": "pro"
              }
            }
            """.data(using: .utf8)
        )
        let limits = try JSONDecoder().decode(RateLimitsReadResult.self, from: data)
        let snapshot = UsageSnapshotMapper.snapshot(limits: limits, usage: nil, fetchedAt: Date(timeIntervalSince1970: 1))

        XCTAssertEqual(snapshot.windows.map(\.id), ["account.primary", "account.secondary"])
        XCTAssertEqual(snapshot.windows.first?.usedPercent, 42.5)
        XCTAssertEqual(snapshot.windows.first?.durationMinutes, 300)
        XCTAssertEqual(snapshot.windows.last?.name, "7일 한도")
        XCTAssertEqual(snapshot.credits?.hasCredits, true)
        XCTAssertEqual(snapshot.credits?.balance, 12.75)
        XCTAssertEqual(snapshot.planName, "pro")
    }

    func testMapperFlattensAllDictionaryBucketsInStableOrderWithoutDuplicateLimit() throws {
        let data = try XCTUnwrap(
            """
            {
              "rateLimits": {
                "limitId": "legacy",
                "primary": { "usedPercent": 10 },
                "credits": { "hasCredits": true },
                "planType": "legacy-plan"
              },
              "rateLimitsByLimitId": {
                "zeta": { "limitId": "zeta", "primary": { "usedPercent": 30 } },
                "alpha": {
                  "limitId": "alpha",
                  "primary": { "usedPercent": 20 },
                  "secondary": { "usedPercent": 40 }
                },
                "duplicate": { "limitId": "legacy", "primary": { "usedPercent": 99 } }
              }
            }
            """.data(using: .utf8)
        )
        let limits = try JSONDecoder().decode(RateLimitsReadResult.self, from: data)
        let snapshot = UsageSnapshotMapper.snapshot(limits: limits, usage: nil, fetchedAt: .now)

        XCTAssertEqual(snapshot.windows.map(\.id), ["legacy.primary", "alpha.primary", "alpha.secondary", "zeta.primary"])
        XCTAssertEqual(snapshot.planName, "legacy-plan")
        XCTAssertEqual(snapshot.credits?.hasCredits, true)
    }

    func testMapperDerivesIndividualSpendControlUsageFromBothProtocolRepresentations() throws {
        let data = try XCTUnwrap(
            """
            {
              "rateLimits": {
                "limitId": "remaining",
                "individualLimit": { "remainingPercent": "25", "resetsAt": 1800000000 }
              },
              "rateLimitsByLimitId": {
                "amount": {
                  "limitId": "amount",
                  "individualLimit": { "limit": 200, "used": 50, "resetsAt": "1800100000" }
                }
              }
            }
            """.data(using: .utf8)
        )
        let limits = try JSONDecoder().decode(RateLimitsReadResult.self, from: data)
        let snapshot = UsageSnapshotMapper.snapshot(limits: limits, usage: nil, fetchedAt: .now)

        XCTAssertEqual(snapshot.windows.map(\.id), ["remaining.individual", "amount.individual"])
        XCTAssertEqual(snapshot.windows.map(\.usedPercent), [75, 25])
        XCTAssertTrue(snapshot.windows.allSatisfy { $0.durationMinutes == nil })
        XCTAssertEqual(snapshot.windows.first?.resetsAt, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func testSpendControlOnlyMarksIndividualWindowWhileGlobalLimitMarksTimeWindows() throws {
        let spendControlData = try XCTUnwrap(
            """
            { "rateLimits": {
              "limitId": "spend",
              "primary": { "usedPercent": 20 },
              "secondary": { "usedPercent": 30 },
              "individualLimit": { "limit": 100, "used": 10 },
              "spendControlReached": true
            }}
            """.data(using: .utf8)
        )
        let globalData = try XCTUnwrap(
            """
            { "rateLimits": {
              "limitId": "global",
              "primary": { "usedPercent": 20 },
              "secondary": { "usedPercent": 30 },
              "rateLimitReachedType": "workspace_usage_limit_reached"
            }}
            """.data(using: .utf8)
        )

        let spend = UsageSnapshotMapper.snapshot(
            limits: try JSONDecoder().decode(RateLimitsReadResult.self, from: spendControlData),
            usage: nil,
            fetchedAt: .now
        )
        let global = UsageSnapshotMapper.snapshot(
            limits: try JSONDecoder().decode(RateLimitsReadResult.self, from: globalData),
            usage: nil,
            fetchedAt: .now
        )

        XCTAssertEqual(spend.windows.map(\.isLimitReached), [false, false, true])
        XCTAssertEqual(global.windows.map(\.isLimitReached), [true, true])
    }
}
