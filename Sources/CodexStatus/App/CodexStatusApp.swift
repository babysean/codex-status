import AppKit
import SwiftUI

@main
struct CodexStatusApp: App {
    @StateObject private var usageStore: UsageStore

    init() {
        let store = UsageStore()
        _usageStore = StateObject(wrappedValue: store)

        Task { @MainActor in
            store.start()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            UsagePopover(store: usageStore)
        } label: {
            MenuBarLabel(
                snapshot: usageStore.snapshot,
                connectionState: usageStore.connectionState
            )
        }
        .menuBarExtraStyle(.window)
    }
}
