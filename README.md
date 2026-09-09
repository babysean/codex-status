# Codex Status

Codex Status는 macOS 메뉴 막대에서 Codex 계정의 사용량과 한도 초기화 시각을 빠르게 확인하는 작은 앱입니다.

메뉴 막대에는 현재 가장 중요한 한도가 `[앱 아이콘] 42%`처럼 표시됩니다. 메뉴를 열면 모든 사용량 한도, 초기화 시각, 크레딧 상태, 누적 토큰과 연결 상태를 확인할 수 있습니다.

## 주요 기능

- Codex 사용량을 메뉴 막대에 퍼센트로 표시
- 계정에 제공되는 모든 단기·장기 한도와 초기화 시각 표시
- 크레딧, 플랜 및 누적 토큰 정보 표시
- 앱 시작 직후 조회하고 60초마다 자동 갱신
- 연결 실패 시 사용량을 0%로 오해하지 않도록 마지막 정상값과 오류 상태를 구분
- Codex의 기존 로그인을 재사용하며 인증 토큰이나 API 키를 별도로 저장하지 않음

## 일반 사용자 설치 방법

일반 사용자는 소스 코드를 내려받아 빌드할 필요가 없습니다. GitHub Release에 첨부된 ZIP 파일을 받아 앱을 설치하는 방식을 권장합니다.

> 현재 무료 배포본은 Apple Developer ID로 공증되지 않은 개발 빌드입니다. 출처가 이 저장소인지 확인한 뒤 설치하세요. 처음 실행할 때 macOS 보안 승인이 한 번 필요할 수 있습니다.

### 1. 실행 환경 확인

현재 배포본의 요구 사항은 다음과 같습니다.

- Apple Silicon Mac(M1, M2, M3, M4 이상)
- macOS 13 Ventura 이상
- ChatGPT 앱, Codex 앱 또는 Codex CLI 설치
- 해당 Codex에서 ChatGPT 계정 로그인 완료

Intel Mac은 현재 배포본에서 지원하지 않습니다.

### 2. Codex 로그인 확인

이미 ChatGPT 또는 Codex 앱에서 Codex를 사용하고 있다면 기존 로그인을 그대로 사용할 수 있습니다.

Codex CLI를 사용하는 경우 터미널에서 다음 명령으로 로그인합니다.

```sh
codex login
```

다음 명령이 정상적으로 버전을 출력하는지도 확인해 주세요.

```sh
codex --version
```

### 3. 앱 다운로드

1. [Codex Status Releases](https://github.com/babysean/codex-status/releases/latest)를 엽니다.
2. `Assets`에서 `Codex-Status-<버전>-arm64.zip` 파일을 다운로드합니다.
3. 다운로드한 ZIP 파일을 더블클릭해 압축을 풉니다.
4. 생성된 `Codex Status.app`을 Finder의 **응용 프로그램** 폴더로 드래그합니다.

아직 Release가 게시되지 않았다면 아래의 [개발자용 초기 설정](#개발자용-초기-설정) 절차로 직접 빌드할 수 있습니다.

### 4. 최초 실행과 macOS 보안 승인

먼저 Finder의 **응용 프로그램** 폴더에서 `Codex Status.app`을 실행합니다.

`Apple에서 악성 소프트웨어가 있는지 확인할 수 없습니다` 또는 개발자를 확인할 수 없다는 메시지가 나오면 다음 순서로 승인합니다.

1. 경고창을 닫습니다.
2. **시스템 설정 → 개인정보 보호 및 보안**을 엽니다.
3. 화면 아래쪽 보안 영역에서 Codex Status 옆의 **확인 없이 열기** 또는 **Open Anyway**를 누릅니다.
4. Mac 로그인 암호 또는 Touch ID로 승인합니다.
5. 다시 표시되는 확인창에서 **열기**를 누릅니다.

승인은 최초 한 번만 필요합니다. 출처가 불분명한 파일에는 이 예외를 적용하지 마세요.

### 5. 사용 방법

앱을 실행하면 Dock 아이콘이나 일반 창 대신 메뉴 막대에 `[앱 아이콘] …%`가 나타납니다.

- 메뉴 막대의 `[앱 아이콘] …%`를 클릭하면 상세 사용량을 볼 수 있습니다.
- 사용량은 앱 시작 직후 조회되며 이후 60초마다 자동으로 갱신됩니다.
- 앱을 닫으려면 메뉴 아래쪽의 **종료**를 누릅니다.
- 데이터가 아직 없거나 연결할 수 없으면 `[앱 아이콘] —`로 표시됩니다.

## 개발자용 초기 설정

### 1. 필요한 도구

- macOS 13 이상
- Xcode Command Line Tools
- Swift 5.9 이상
- 로그인된 Codex CLI 또는 ChatGPT/Codex 앱
- Git

Xcode Command Line Tools가 없다면 다음 명령으로 설치를 시작합니다.

```sh
xcode-select --install
```

설치 상태를 확인합니다.

```sh
swift --version
git --version
codex --version
```

### 2. 저장소 받기

```sh
git clone https://github.com/babysean/codex-status.git
cd codex-status
```

### 3. 개발 모드로 실행

```sh
swift run CodexStatus
```

실행 후 메뉴 막대에서 `[앱 아이콘] …%` 항목을 찾습니다. 터미널에서 실행한 경우 `Control-C`로 종료할 수 있습니다.

### 4. 테스트와 빌드

```sh
swift test
swift build
```

현재 환경에서 `no such module 'XCTest'`가 발생한다면 Xcode 또는 Command Line Tools 설치가 올바른지 확인하고, Xcode와 SDK 버전을 맞춰 주세요.

### 5. `.app` 만들기

프로젝트에 포함된 스크립트가 release 실행 파일을 빌드하고, 앱 번들을 만든 뒤 로컬 ad-hoc 서명과 서명 검증을 수행합니다.

```sh
./Scripts/build-app.sh
```

완료되면 다음 위치에 앱이 생성됩니다.

```text
dist/Codex Status.app
```

로컬 Applications 폴더에 설치하려면 다음 명령을 사용합니다.

```sh
ditto "dist/Codex Status.app" "/Applications/Codex Status.app"
open -a "/Applications/Codex Status.app"
```

기존 설치본을 교체할 때는 실행 중인 Codex Status를 먼저 종료해 주세요.

## 배포 파일 만들기

`.app` 디렉터리를 Git 커밋에 직접 포함하기보다는 ZIP으로 묶어 GitHub Releases의 Asset으로 올리는 것을 권장합니다. 저장소에는 소스와 빌드 방법이 남고, Release에는 사용자가 바로 설치할 수 있는 앱이 남아 버전 관리가 명확해집니다.

### 1. 앱 빌드

```sh
./Scripts/build-app.sh
```

### 2. ZIP과 체크섬 생성

아래 예시는 버전 `0.1.0`의 Apple Silicon 배포 파일을 만듭니다.

```sh
mkdir -p dist/release

ditto -c -k --sequesterRsrc --keepParent \
  "dist/Codex Status.app" \
  "dist/release/Codex-Status-0.1.0-arm64.zip"

shasum -a 256 \
  "dist/release/Codex-Status-0.1.0-arm64.zip" \
  > "dist/release/SHA256SUMS.txt"
```

### 3. GitHub Release 게시

GitHub의 **Releases → Draft a new release**에서 다음과 같이 게시합니다.

- 태그: `v0.1.0`
- 제목: `Codex Status 0.1.0`
- 첨부 파일:
  - `Codex-Status-0.1.0-arm64.zip`
  - `SHA256SUMS.txt`

Release Asset은 Git 커밋에 포함하거나 `git push`하는 파일이 아닙니다. 태그를 push한 뒤 GitHub Release 화면이나 GitHub CLI로 별도 업로드합니다.

## 문제 해결

### 메뉴 막대에 `[앱 아이콘] —`가 계속 표시됩니다

1. ChatGPT/Codex 앱이나 Codex CLI에서 로그인되어 있는지 확인합니다.
2. 자동 갱신을 위해 최대 60초 기다립니다.
3. 계속 표시되면 Codex Status를 종료했다가 다시 실행합니다.

CLI를 사용한다면 다음 명령도 확인합니다.

```sh
codex --version
```

### `Codex 없음`이 표시됩니다

앱은 다음 순서로 Codex 실행 파일을 찾습니다.

- `/Applications/ChatGPT.app/Contents/Resources/codex`
- `/Applications/Codex.app/Contents/Resources/codex`
- `/opt/homebrew/bin/codex`
- `/usr/local/bin/codex`
- 현재 `PATH` 안의 `codex`

위 위치 중 하나에 실행 가능한 Codex가 있는지 확인하세요.

### `로그인 필요`가 표시됩니다

터미널에서 `codex login`을 실행하거나 ChatGPT/Codex 앱에서 다시 로그인한 뒤 최대 60초 기다리세요. 바로 확인하려면 Codex Status를 다시 실행합니다.

### `업데이트 필요`가 표시됩니다

설치된 Codex App Server의 프로토콜과 이 앱이 지원하는 형식이 다른 상태입니다. ChatGPT/Codex 앱 또는 Codex CLI와 Codex Status를 최신 버전으로 업데이트한 뒤 다시 시도하세요.

### 앱을 제거하고 싶습니다

Codex Status 메뉴에서 먼저 **종료**한 후 Finder의 **응용 프로그램** 폴더에서 `Codex Status.app`을 휴지통으로 이동합니다.

## 개인정보와 보안

- Codex Status는 Codex의 로컬 App Server와 통신합니다.
- 계정 토큰, 쿠키, API 키 또는 `auth.json`을 읽거나 복사하거나 저장하지 않습니다.
- Codex의 기존 로그인 세션은 Codex App Server가 관리합니다.
- 연결 오류를 사용량 0%로 표시하지 않고, 마지막 정상 데이터와 오류 상태를 구분합니다.
- 무료 배포본은 ad-hoc 서명만 적용되고 Apple 공증은 받지 않았습니다.

구현 배경과 세부 설계는 [DESIGN.md](DESIGN.md)에서 확인할 수 있습니다.

## 메뉴바 아이콘

Codex 아이콘은 [LobeHub Icons](https://lobehub.com/icons)의 정적 PNG를 사용합니다. [사용 지침](https://lobehub.com/icons/skill.md)에 따라 Swift 앱에는 React 패키지 대신 정적 에셋을 포함했습니다. MIT 라이선스 사본은 앱 리소스에 포함됩니다.
