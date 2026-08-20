import Foundation
import SwiftUI

enum UsageSeverity {
    case normal, warning, critical, limitReached

    init(window: UsageWindow) {
        if window.isLimitReached || window.usedPercent >= 100 { self = .limitReached }
        else if window.usedPercent >= 95 { self = .critical }
        else if window.usedPercent >= 80 { self = .warning }
        else { self = .normal }
    }

    var label: String {
        switch self {
        case .normal: "정상"
        case .warning: "주의: 한도에 가까움"
        case .critical: "위험: 한도에 매우 가까움"
        case .limitReached: "사용 제한: 한도 도달"
        }
    }

    var color: Color {
        switch self {
        case .normal: .secondary
        case .warning: .orange
        case .critical, .limitReached: .red
        }
    }
}

struct ConnectionStatePresentation {
    enum Kind { case loading, connected, stale, unavailable }

    let state: ConnectionState

    init(_ state: ConnectionState) { self.state = state }

    var kind: Kind {
        switch state {
        case .loading: .loading
        case .connected: .connected
        case .stale: .stale
        case .unauthenticated, .codexNotFound, .incompatibleProtocol, .failed: .unavailable
        }
    }

    var label: String { state.statusText }

    var symbolName: String {
        switch kind {
        case .loading: "arrow.triangle.2.circlepath"
        case .connected: "checkmark.circle"
        case .stale: "clock.badge.exclamationmark"
        case .unavailable: "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch kind {
        case .loading, .stale: .orange
        case .connected: .green
        case .unavailable: .red
        }
    }
}

enum DisplayValue {
    static func credits(_ credits: CreditStatus) -> String {
        if credits.isUnlimited { return "무제한" }
        guard credits.hasCredits else { return "사용 가능한 크레딧 없음" }
        guard let balance = credits.balance else { return "사용 가능" }
        return "잔액 \(balance.formatted(.number.precision(.fractionLength(0...2))))"
    }

    static func lifetimeTokens(_ summary: TokenSummary) -> String? {
        summary.lifetimeTokens?.formatted(.number.notation(.compactName))
    }
}

enum PresentationFormatters {
    static func percent(_ percent: Double) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: percent / 100), number: .percent)
    }

    static func duration(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)분 한도" }
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)시간 한도" : "\(hours)시간 \(remainder)분 한도"
    }

    static func resetDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 MM월 dd일 HH시 mm분 ss초"
        return formatter.string(from: date)
    }
}
