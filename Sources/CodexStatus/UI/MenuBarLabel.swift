import SwiftUI

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot?
    let connectionState: ConnectionState

    var body: some View {
        Text(title)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Codex 사용량 상세 정보를 엽니다.")
    }

    private var title: String {
        guard let window = snapshot?.representativeWindow else { return "Codex —" }
        return "Codex \(PresentationFormatters.percent(window.usedPercent))"
    }

    private var accessibilityLabel: String {
        guard let window = snapshot?.representativeWindow else {
            return "Codex 사용량, \(ConnectionStatePresentation(connectionState).label)"
        }
        return "Codex \(window.name), \(PresentationFormatters.percent(window.usedPercent)) 사용, \(UsageSeverity(window: window).label)"
    }
}
