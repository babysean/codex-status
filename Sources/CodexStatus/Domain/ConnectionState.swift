import Foundation

enum ConnectionState: Sendable, Equatable {
    case loading
    case connected
    case stale(lastSuccess: Date)
    case unauthenticated
    case codexNotFound
    case incompatibleProtocol(details: String)
    case failed(details: String)

    var statusText: String {
        switch self {
        case .loading:
            return "불러오는 중"
        case .connected:
            return "정상"
        case .stale:
            return "마지막 정상 데이터 표시 중"
        case .unauthenticated:
            return "Codex 로그인이 필요함"
        case .codexNotFound:
            return "Codex CLI를 찾을 수 없음"
        case .incompatibleProtocol:
            return "지원하지 않는 Codex 버전"
        case .failed:
            return "연결 실패"
        }
    }
}
