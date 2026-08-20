# Codex Status 설계서

## 1. 문서 정보

- 애플리케이션명: Codex Status
- 대상 플랫폼: macOS
- 프로젝트 위치: `/Users/sanghoon/Personal/codex-status`
- 문서 상태: 구현 전 초안
- 최종 사용자: 로컬 Mac에서 ChatGPT 계정으로 Codex를 사용하는 사용자

## 2. 목표

Codex 계정의 사용량과 한도 상태를 macOS 메뉴 막대에서 빠르게 확인할 수 있는 경량 애플리케이션을 만든다.

사용자는 Codex 또는 브라우저를 열지 않고 다음 정보를 확인할 수 있어야 한다.

- 대표 사용량의 현재 사용 비율
- 단기 및 장기 사용 한도의 사용 비율과 초기화 시각
- 크레딧 잔액 또는 크레딧 사용 가능 여부
- 데이터 갱신 시각과 연결 상태
- 사용량 임계치 도달 여부

## 3. 비목표

초기 버전에서는 다음 기능을 제공하지 않는다.

- OpenAI 계정 로그인 UI 또는 자격 증명 관리
- API 키를 이용한 별도 과금 조회
- Codex 작업 생성·중단·수정
- 여러 OpenAI 계정 동시 관리
- 사용량 예측 또는 비용 예측
- App Store 배포
- iOS 또는 Windows 지원

## 4. 제품 원칙

1. 메뉴 막대에서 한눈에 읽혀야 한다.
2. 기존 Codex 로그인을 재사용하며 인증 정보를 복사하거나 저장하지 않는다.
3. Codex가 실행 중이지 않거나 네트워크가 끊겨도 메뉴바 앱 자체는 안정적으로 유지한다.
4. 조회 실패를 사용량 0%로 오인하지 않도록 마지막 정상값과 오류 상태를 구분한다.
5. 실험적인 Codex App Server 프로토콜 변경을 UI와 분리한다.

## 5. 사용자 경험

### 5.1 메뉴 막대 표시

기본 표시는 가장 중요한 한도의 사용 비율을 짧게 보여준다.

```text
Codex 42%
```

상태별 예시:

```text
Codex 42%   정상
Codex 82%   주의
Codex 96%   위험
Codex —     연결 안 됨 또는 데이터 없음
```

색상만으로 상태를 전달하지 않는다. macOS의 템플릿 아이콘과 텍스트를 사용하고, 상세 메뉴에 상태 문구를 함께 표시한다.

### 5.2 메뉴 팝오버

메뉴 막대 항목을 클릭하면 다음 정보를 표시한다.

```text
Codex 사용량

5시간 한도       42% 사용
초기화           오늘 18:30

주간 한도        18% 사용
초기화           8월 18일 09:00

크레딧           사용 가능
마지막 갱신      15:48:12
상태              정상

지금 새로고침
로그인 시 자동 실행  ✓
설정…
Codex Status 종료
```

서버가 한도의 이름이나 기간을 다르게 제공하면 고정된 “5시간/주간” 문구 대신 서버의 이름과 기간을 표시한다.

### 5.3 임계치

기본 임계치는 다음과 같다.

- 0~79%: 정상
- 80~94%: 주의
- 95% 이상: 위험
- 100% 또는 한도 도달 응답: 사용 제한

알림은 기본적으로 꺼 두고 설정에서 활성화한다. 같은 한도 구간에 대한 알림은 초기화 전까지 한 번만 보낸다.

## 6. 기술 구성

### 6.1 권장 기술 스택

- 언어: Swift
- UI: SwiftUI
- 메뉴 막대: `MenuBarExtra`
- 최소 macOS 버전: macOS 13 Ventura
- 프로젝트 형식: Swift Package Manager 기반 실행 앱 또는 Xcode 프로젝트
- 자동 실행: `SMAppService.mainApp`
- 로깅: `OSLog`
- 테스트: XCTest

네이티브 Swift 앱을 선택하는 이유는 별도 런타임이나 메뉴바 유틸리티 설치 없이 `.app` 하나로 실행할 수 있고, 자동 실행·알림·키체인 등 macOS 기능과 자연스럽게 통합되기 때문이다.

### 6.2 논리 구조

```text
CodexStatusApp
├── UI
│   ├── MenuBarLabel
│   ├── UsagePopover
│   └── SettingsView
├── Domain
│   ├── UsageSnapshot
│   ├── UsageWindow
│   └── ConnectionState
├── Services
│   ├── UsageProvider
│   ├── CodexAppServerProvider
│   ├── RefreshScheduler
│   ├── NotificationService
│   └── LaunchAtLoginService
└── Infrastructure
    ├── AppServerClient
    ├── JSONRPCTransport
    ├── SnapshotCache
    └── Logger
```

UI는 App Server의 원본 JSON 형식을 직접 참조하지 않는다. `UsageProvider`가 프로토콜 응답을 앱 내부 모델인 `UsageSnapshot`으로 변환한다.

## 7. 데이터 소스 및 연동

### 7.1 1차 데이터 소스

로컬 Codex App Server의 JSON-RPC 인터페이스를 사용한다.

필요한 메서드:

- `initialize`
- `account/read`
- `account/rateLimits/read`
- `account/usage/read`

선택적으로 다음 알림을 구독한다.

- `account/rateLimits/updated`
- `thread/tokenUsage/updated`

`account/rateLimits/read` 응답에서 다음 값을 사용한다.

- 한도 식별자 및 표시 이름
- primary/secondary 사용 비율
- 윈도우 기간
- 초기화 시각
- 크레딧 상태와 잔액
- 요금제 유형
- 한도 도달 상태

`account/usage/read` 응답은 누적 토큰과 일별 사용량을 지원하는 경우 상세 화면에 표시한다. 이 정보가 제공되지 않아도 핵심 한도 UI는 정상 동작해야 한다.

### 7.2 연결 전략

우선순위는 다음과 같다.

1. 실행 중인 Codex App Server의 로컬 제어 소켓에 연결한다.
2. 연결 가능한 공유 런타임이 없다면 `codex app-server`를 자식 프로세스로 실행하여 stdio로 통신한다.
3. Codex CLI를 찾을 수 없거나 인증되지 않았다면 오류 상태를 표시하고 설치·로그인 안내를 제공한다.

Codex 실행 파일 탐색 순서:

1. 사용자가 설정에서 지정한 경로
2. `/Applications/Codex.app/Contents/Resources/codex`
3. 로그인 셸이 아닌 고정 후보 경로(`/opt/homebrew/bin/codex`, `/usr/local/bin/codex`)
4. `/usr/bin/env codex`

실행 파일은 실행 전 존재 여부와 실행 가능 여부를 확인한다.

### 7.3 프로토콜 호환성

App Server는 실험적 인터페이스이므로 다음 방어 장치를 둔다.

- JSON 디코딩 시 알려지지 않은 필드는 무시한다.
- 선택 필드는 `nil`을 허용한다.
- 앱 시작 시 지원 메서드와 응답 구조를 검증한다.
- 프로토콜 오류와 인증 오류를 구분한다.
- 마지막 정상 스냅샷을 유지하되 “마지막 갱신 시각”을 항상 표시한다.
- Codex 버전을 진단 정보에 기록한다.

## 8. 갱신 정책

- 앱 시작 직후 조회
- 기본 주기: 60초
- 메뉴 팝오버를 열 때 즉시 조회
- 사용량 갱신 알림 수신 시 디바운스 후 조회
- 실패 시 재시도: 5초 → 15초 → 30초 → 최대 5분
- 정상 응답 후 기본 주기로 복귀
- 시스템 잠자기 중에는 타이머를 중지하고 깨어날 때 즉시 조회

동시에 여러 조회가 실행되지 않도록 단일 비동기 갱신 작업으로 직렬화한다.

## 9. 상태 모델

```swift
struct UsageSnapshot: Sendable {
    let windows: [UsageWindow]
    let credits: CreditStatus?
    let planName: String?
    let tokenSummary: TokenSummary?
    let fetchedAt: Date
}

struct UsageWindow: Identifiable, Sendable {
    let id: String
    let name: String
    let usedPercent: Double
    let durationMinutes: Int?
    let resetsAt: Date?
}

enum ConnectionState: Sendable {
    case loading
    case connected
    case stale(lastSuccess: Date)
    case unauthenticated
    case codexNotFound
    case incompatibleProtocol(details: String)
    case failed(details: String)
}
```

메뉴 막대 대표값은 다음 순서로 선택한다.

1. 이미 도달한 한도
2. 사용 비율이 가장 높은 활성 한도
3. 서버가 primary로 지정한 한도
4. 데이터가 없으면 `—`

## 10. 로컬 저장

`UserDefaults`에 다음 설정만 저장한다.

- 갱신 주기
- 주의·위험 임계치
- 알림 활성화 여부
- 로그인 시 자동 실행 여부
- 사용자 지정 Codex 실행 파일 경로
- 메뉴 막대 표시 형식

마지막 정상 사용량 스냅샷은 Application Support 아래에 저장할 수 있다. 인증 토큰, 쿠키, API 키, Codex의 `auth.json` 내용은 읽거나 복사하거나 저장하지 않는다.

## 11. 보안 및 개인정보

- 네트워크 요청을 앱이 직접 OpenAI 서버로 보내지 않는다.
- 인증은 Codex App Server가 소유하며 앱은 로컬 프로토콜만 사용한다.
- 로컬 소켓 또는 자식 프로세스 stdio 외의 외부 수신 포트를 열지 않는다.
- 로그에 계정 식별자, 토큰, 원본 인증 응답을 기록하지 않는다.
- 진단 로그에는 Codex 버전, 상태 코드, 메서드명, 오류 종류만 기록한다.
- 프로세스 실행 시 셸 문자열 조합 대신 `Process.executableURL`과 인자 배열을 사용한다.

## 12. 오류 처리

| 상황 | 사용자 표시 | 처리 |
|---|---|---|
| Codex CLI 없음 | `Codex —` | 설치 위치 안내, 자동 재탐색 |
| 로그인 안 됨 | `로그인 필요` | `codex login` 실행 안내 |
| App Server 연결 실패 | 마지막 값 + `오래됨` | 백오프 재연결 |
| 프로토콜 변경 | `업데이트 필요` | 원본 오류 대신 호환성 안내 |
| 네트워크 오류 | 마지막 값 + `오프라인` | 연결 복구 시 자동 갱신 |
| 데이터 일부 누락 | 제공된 항목만 표시 | 앱 전체 실패로 처리하지 않음 |
| 한도 도달 | `Codex 100%` | 위험 상태와 초기화 시각 표시 |

## 13. 자동 실행과 배포

개발 빌드는 로컬에서 서명하여 `/Applications/Codex Status.app` 또는 사용자 Applications 폴더에 설치한다.

로그인 시 자동 실행은 `SMAppService.mainApp.register()`를 사용한다. 사용자가 설정에서 끄면 즉시 등록을 해제한다.

초기 배포 산출물:

- `Codex Status.app`
- 설치 및 제거 방법을 담은 `README.md`
- 개발자용 빌드 명령

공개 배포로 확장할 경우 Developer ID 서명, Hardened Runtime, 공증을 추가한다.

## 14. 테스트 전략

### 14.1 단위 테스트

- rate limit JSON을 내부 모델로 변환
- primary/secondary 값이 없는 응답 처리
- 대표 한도 선택 규칙
- 임계치 상태 판정
- 초기화 시각 및 기간 표시
- 백오프 계산
- 마지막 정상값과 오류 상태 병합

### 14.2 통합 테스트

- 가짜 JSON-RPC 서버와 initialize 흐름
- rate limit 및 usage 조회
- 알림 수신 후 갱신
- 프로세스 종료 후 재연결
- 인증되지 않은 응답
- 알 수 없는 필드가 추가된 응답

### 14.3 수동 확인

- 메뉴 막대의 밝은/어두운 테마
- 노치가 있는 Mac에서 좁은 공간 표시
- 시스템 잠자기와 깨우기
- Codex 앱 실행 전·후 연결
- 오프라인 전환과 복구
- 로그인 시 자동 실행
- VoiceOver 레이블과 키보드 접근

## 15. 구현 단계

### 단계 0: 연동 검증

- 현재 설치된 Codex App Server에 연결
- `account/rateLimits/read` 실제 응답 확인
- `account/usage/read` 지원 여부 확인
- 인증 정보를 별도로 취급하지 않고 조회 가능한지 확인

완료 조건: 실제 계정의 최소 한도 하나를 터미널에서 구조화된 값으로 읽는다.

### 단계 1: 최소 기능 제품

- SwiftUI 메뉴바 앱 생성
- 사용량 조회와 60초 자동 갱신
- 대표 퍼센트 표시
- 상세 메뉴와 수동 새로고침
- 연결 오류 및 마지막 갱신 시각 표시

완료 조건: 앱을 30분 이상 실행하며 실제 사용량 변화와 재연결을 확인한다.

### 단계 2: 안정화

- 로그인 시 자동 실행
- 백오프와 잠자기 복귀 처리
- 마지막 정상 스냅샷 캐시
- 단위·통합 테스트
- 진단 정보 복사 기능

### 단계 3: 편의 기능

- 임계치 알림
- 메뉴 표시 형식 설정
- 토큰 통계 상세 화면
- 로컬 서명 앱 패키징

## 16. 예상 프로젝트 구조

```text
codex-status/
├── README.md
├── DESIGN.md
├── Package.swift
├── Sources/
│   └── CodexStatus/
│       ├── App/
│       ├── Domain/
│       ├── Services/
│       ├── Infrastructure/
│       └── UI/
├── Tests/
│   └── CodexStatusTests/
├── Scripts/
│   ├── build-app.sh
│   └── install-local.sh
└── Resources/
    └── Assets.xcassets/
```

Xcode 프로젝트가 앱 번들·에셋·서명 관리에 더 유리하다고 확인되면 `Package.swift` 대신 `.xcodeproj`를 사용하되 논리 디렉터리 구조는 유지한다.

## 17. 완료 기준

- 메뉴 막대에서 실제 Codex 사용 비율을 확인할 수 있다.
- 상세 메뉴에서 모든 제공 한도와 초기화 시각을 확인할 수 있다.
- Codex 또는 네트워크 장애 시 앱이 종료되지 않고 상태를 정확히 표시한다.
- 인증 비밀을 앱이 저장하지 않는다.
- 로그인 시 자동 실행을 사용자가 켜고 끌 수 있다.
- 핵심 변환 및 상태 판정 로직에 자동 테스트가 있다.
- 설치·실행·제거 방법이 문서화되어 있다.

## 18. 주요 위험과 대응

| 위험 | 영향 | 대응 |
|---|---|---|
| App Server 프로토콜 변경 | 조회 실패 | 어댑터 격리, 관대한 디코딩, 버전 진단 |
| 공유 런타임 접근 불가 | 별도 프로세스 필요 | stdio App Server 폴백 |
| 계정별 한도 구조 차이 | 고정 UI 오표시 | 서버가 제공한 한도 목록 기반 동적 UI |
| 인증 세션 만료 | 사용량 조회 중단 | 로그인 필요 상태와 명령 안내 |
| 메뉴 막대 공간 부족 | 텍스트 잘림 | 짧은 표시 모드와 아이콘 전용 모드 |
| 과도한 조회 | 불필요한 부하 | 60초 주기, 알림 기반 갱신, 백오프 |

## 19. 구현 전 확인 사항

단계 0에서 아래 사항을 실제 환경으로 확정한다.

1. 공유 App Server 소켓의 안정적인 탐색 방법
2. 앱 내장 CLI와 Homebrew CLI 중 우선 사용할 런타임
3. 계정에서 반환되는 실제 limit 이름과 개수
4. `account/usage/read`가 반환하는 토큰 통계 범위
5. Codex 앱이 종료된 상태에서 자식 App Server 실행이 허용되는지

이 확인 결과가 달라도 UI와 도메인 설계는 유지하고 `CodexAppServerProvider`만 조정한다.
