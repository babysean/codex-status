import AppKit
import SwiftUI

struct UsagePopover: View {
    @ObservedObject var store: UsageStore
    @State private var showsResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Codex 사용량")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                ConnectionStateBadge(state: store.connectionState)
            }

            Divider()
            usageContent
            Divider()
            details
            Divider()
            controls
        }
        .padding(16)
        .frame(width: 340)
        .background(Color.white)
        .preferredColorScheme(.light)
        .accessibilityElement(children: .contain)
        .task { await store.refresh() }
        .confirmationDialog(
            "사용한도를 초기화할까요?",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("초기화 크레딧 사용", role: .destructive) {
                Task { await store.resetUsageLimit() }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("보유한 초기화 크레딧 1개를 사용합니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .alert(
            "사용한도 초기화",
            isPresented: Binding(
                get: { store.resetResultMessage != nil },
                set: { if !$0 { store.resetResultMessage = nil } }
            )
        ) {
            Button("확인") { store.resetResultMessage = nil }
        } message: {
            Text(store.resetResultMessage ?? "")
        }
    }

    @ViewBuilder private var usageContent: some View {
        if let snapshot = store.snapshot, !snapshot.windows.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(snapshot.windows) { UsageWindowRow(window: $0) }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("사용량 데이터 없음").font(.headline)
                Text(emptyDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var details: some View {
        if let snapshot = store.snapshot {
            VStack(alignment: .leading, spacing: 8) {
                if let plan = snapshot.planName, !plan.isEmpty { DetailRow(label: "플랜", value: plan) }
                if let credits = snapshot.credits { DetailRow(label: "크레딧", value: DisplayValue.credits(credits)) }
                if let tokens = snapshot.tokenSummary, let total = DisplayValue.lifetimeTokens(tokens) {
                    DetailRow(label: "누적 토큰", value: total)
                }
            }
        } else {
            DetailRow(label: "상태", value: ConnectionStatePresentation(store.connectionState).label)
        }
    }

    private var controls: some View {
        HStack {
            Button {
                showsResetConfirmation = true
            } label: {
                Label(store.isResetting ? "초기화 중" : "사용한도 초기화", systemImage: "arrow.counterclockwise.circle")
            }
            .disabled(!store.canResetUsageLimit)
            .accessibilityHint("사용 가능한 초기화 크레딧으로 Codex 사용한도를 초기화합니다.")

            Spacer()

            Button("종료", role: .destructive) { NSApplication.shared.terminate(nil) }
                .accessibilityHint("Codex Status를 종료합니다.")
        }
    }

    private var emptyDescription: String {
        switch ConnectionStatePresentation(store.connectionState).kind {
        case .loading: "Codex 사용량을 불러오는 중입니다."
        case .connected: "현재 계정에서 보고할 한도가 없습니다."
        case .stale: "마지막으로 받은 데이터가 오래되었습니다."
        case .unavailable: "Codex 로그인과 연결 상태를 확인해 주세요."
        }
    }
}

private struct UsageWindowRow: View {
    let window: UsageWindow
    private var severity: UsageSeverity { UsageSeverity(window: window) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.name).fontWeight(.medium)
                Spacer()
                Text("\(PresentationFormatters.percent(window.usedPercent)) 사용")
                    .monospacedDigit()
                    .foregroundStyle(severity.color)
            }
            ProgressView(value: min(max(window.usedPercent / 100, 0), 1))
                .tint(severity.color)
                .accessibilityLabel("\(window.name) 사용량")
                .accessibilityValue("\(PresentationFormatters.percent(window.usedPercent)) 사용, \(severity.label)")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(severity.label)
                    .font(.caption).fontWeight(.semibold).foregroundStyle(severity.color)
                Spacer()
                Text(resetText)
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var resetText: String {
        var parts: [String] = []
        if let minutes = window.durationMinutes { parts.append(PresentationFormatters.duration(minutes: minutes)) }
        if let reset = window.resetsAt { parts.append("\(PresentationFormatters.resetDate(reset)) 초기화") }
        return parts.isEmpty ? "초기화 시각 미제공" : parts.joined(separator: " · ")
    }
}

private struct ConnectionStateBadge: View {
    let state: ConnectionState

    var body: some View {
        let presentation = ConnectionStatePresentation(state)
        Label(presentation.label, systemImage: presentation.symbolName)
            .font(.caption)
            .foregroundStyle(presentation.color)
            .accessibilityLabel("연결 상태: \(presentation.label)")
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.callout)
        .accessibilityElement(children: .combine)
    }
}
