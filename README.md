# Codex Status

macOS 메뉴 막대에서 Codex 계정의 사용량, 한도 초기화 시각, 연결 상태를 확인하는 경량 앱입니다. 기존 Codex CLI 로그인을 재사용하며 인증 정보나 API 키를 저장하지 않습니다.

## 요구 사항

- macOS 13 Ventura 이상
- Swift 5.9 이상 (개발·빌드 시)
- 로그인된 Codex CLI (`codex login`)

이 앱은 로컬 `codex app-server`에만 연결합니다. OpenAI 서버로 직접 요청하지 않습니다.

## 개발 실행

저장소 루트에서 실행합니다.

```sh
swift run CodexStatus
```

메뉴 막대에 `Codex 42%`처럼 표시됩니다. 사용량을 아직 읽지 못했거나 Codex 연결에 실패하면 `Codex —`가 표시됩니다. 메뉴를 열어 전체 한도, 초기화 시각, 크레딧, 마지막 갱신 및 상세 연결 상태를 확인할 수 있습니다.

## 테스트와 빌드

```sh
swift test
swift build -c release
```

## .app 만들기와 설치

다음 명령은 release 실행 파일을 `dist/Codex Status.app`으로 묶습니다.

```sh
./Scripts/build-app.sh
```

Finder에서 생성된 앱을 `Applications` 폴더로 드래그하거나, 터미널에서 설치합니다.

```sh
cp -R "dist/Codex Status.app" /Applications/
```

개발 빌드는 로컬 ad-hoc 서명만 포함하며 공증되지 않았습니다. 처음 열 때 macOS 보안 경고가 표시될 수 있으며, Finder에서 앱을 Control-클릭한 뒤 **열기**를 선택하면 됩니다. 공개 배포 전에는 Developer ID 서명과 공증을 추가해야 합니다.

## 문제 해결

- `Codex —`가 계속 보이면 `codex login`을 실행한 뒤 메뉴의 **지금 새로고침**을 선택하세요.
- `Codex 없음`이면 Codex 앱 또는 CLI를 설치하고, 기본 경로(`/Applications/ChatGPT.app/Contents/Resources/codex`, `/Applications/Codex.app/Contents/Resources/codex`, `/opt/homebrew/bin/codex`, `/usr/local/bin/codex`)에 실행 파일이 있는지 확인하세요.
- `업데이트 필요`는 설치된 Codex App Server 프로토콜이 이 앱이 지원하는 형식과 다름을 뜻합니다. Codex와 Codex Status를 업데이트한 뒤 다시 시도하세요.

## 개인정보

Codex Status는 계정 토큰, 쿠키, API 키 또는 `auth.json`을 읽거나 복사하거나 저장하지 않습니다. 연결 오류를 사용량 0%로 표시하지 않으며 마지막으로 정상 수신한 데이터는 오래됨 상태로 구분합니다.
