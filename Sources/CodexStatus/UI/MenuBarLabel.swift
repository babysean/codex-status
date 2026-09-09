import AppKit
import Combine
import SwiftUI

/// Owns the AppKit status item so the menu bar always receives a concrete image.
@MainActor
final class MenuBarController: NSObject {
    private let store: UsageStore
    private(set) var statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        super.init()

        configureStatusButton()
        configurePopover()
        observeStore()
        updateStatusButton(snapshot: store.snapshot, connectionState: store.connectionState)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.image = Self.menuBarIcon
        button.imagePosition = .imageLeading
        button.imageScaling = .scaleProportionallyDown
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        button.toolTip = "Codex 사용량"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: UsagePopover(store: store))
    }

    private func observeStore() {
        Publishers.CombineLatest(store.$snapshot, store.$connectionState)
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot, connectionState in
                self?.updateStatusButton(snapshot: snapshot, connectionState: connectionState)
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton(snapshot: UsageSnapshot?, connectionState: ConnectionState) {
        guard let button = statusItem.button else { return }
        let percentage = snapshot?.representativeWindow.map { PresentationFormatters.percent($0.usedPercent) } ?? "—"
        button.title = percentage
        button.image = Self.menuBarIcon
        button.imagePosition = .imageLeading
        button.setAccessibilityLabel(accessibilityLabel(snapshot: snapshot, connectionState: connectionState))
        button.setAccessibilityHelp("Codex 사용량 상세 정보를 엽니다.")
        button.toolTip = button.accessibilityLabel()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func accessibilityLabel(snapshot: UsageSnapshot?, connectionState: ConnectionState) -> String {
        guard let window = snapshot?.representativeWindow else {
            return "Codex 사용량, \(ConnectionStatePresentation(connectionState).label)"
        }
        return "Codex \(window.name), \(PresentationFormatters.percent(window.usedPercent)) 사용, \(UsageSeverity(window: window).label), \(ConnectionStatePresentation(connectionState).label)"
    }

    private static let menuBarIcon: NSImage? = {
        let bundle = Bundle.main.url(forResource: "CodexStatus_CodexStatus", withExtension: "bundle")
            .flatMap { Bundle(url: $0) } ?? Bundle.module
        guard let url = bundle.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = true
        return image
    }()
}
