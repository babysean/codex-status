import Foundation
import XCTest
@testable import CodexStatus

@MainActor
final class UsageStoreTests: XCTestCase {
    func testRefreshPublishesFetchedSnapshot() async {
        let snapshot = makeSnapshot()
        let provider = SequenceUsageProvider(results: [.success(snapshot)])
        let store = UsageStore(provider: provider, refreshInterval: .seconds(60))

        await store.refresh()

        XCTAssertEqual(store.snapshot, snapshot)
        XCTAssertEqual(store.connectionState, .connected)
        XCTAssertFalse(store.isRefreshing)
    }

    func testRefreshKeepsLastSuccessAsStaleAfterFailure() async {
        let snapshot = makeSnapshot()
        let provider = SequenceUsageProvider(results: [.success(snapshot), .failure(TestFailure())])
        let store = UsageStore(provider: provider, refreshInterval: .seconds(60))

        await store.refresh()
        await store.refresh()

        XCTAssertEqual(store.snapshot, snapshot)
        XCTAssertEqual(store.connectionState, .stale(lastSuccess: snapshot.fetchedAt))
    }

    private func makeSnapshot() -> UsageSnapshot {
        UsageSnapshot(
            windows: [UsageWindow(id: "main", name: "Main", usedPercent: 10)],
            credits: nil,
            resetCreditsAvailable: 0,
            planName: nil,
            tokenSummary: nil,
            fetchedAt: Date(timeIntervalSince1970: 100)
        )
    }
}

private actor SequenceUsageProvider: UsageProvider {
    private var results: [Result<UsageSnapshot, TestFailure>]

    init(results: [Result<UsageSnapshot, TestFailure>]) {
        self.results = results
    }

    func fetchUsage() throws -> UsageSnapshot {
        guard results.isEmpty == false else { throw TestFailure() }
        return try results.removeFirst().get()
    }
}

private struct TestFailure: Error {}
