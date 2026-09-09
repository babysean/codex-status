import AppKit
import SwiftUI

@main
struct CodexStatusApp: App {
    @NSApplicationDelegateAdaptor(CodexStatusAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class CodexStatusAppDelegate: NSObject, NSApplicationDelegate {
    private let usageStore = UsageStore()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(store: usageStore)
        usageStore.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageStore.stop()
    }
}
