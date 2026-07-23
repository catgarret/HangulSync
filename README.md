<p align="center">
  <img src="assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

**한국어** | [English](docs/README.en.md) | [日本語](docs/README.ja.md) | [简体中文](docs/README.zh-CN.md) | [繁體中文](docs/README.zh-TW.md) | [ไทย](docs/README.th.md) | [Русский](docs/README.ru.md) | [Italiano](docs/README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**Mac 간 한/영 입력 소스를 실시간 동기화**하는 초경량 메뉴바 앱. **Jump Desktop**, Screens, 화면 공유 등 원격 데스크탑 사용 시 발생하는 **한글 자소 분리(`ㅎㅏㄴㄱㅡㄹ`)** 와 한영 전환 불일치, cmd 키 오작동 문제를 근본적으로 해결합니다.

한쪽 Mac에서 한/영을 전환하면 연결된 모든 Mac이 즉시 같은 상태로 전환됩니다. **IP 입력 등 설정이 전혀 필요 없습니다.**

## 왜 필요한가요?

원격 데스크탑으로 다른 Mac을 조작하면 로컬과 원격의 입력 소스가 쉽게 어긋납니다. 나는 한글을 친다고 생각하는데 원격 Mac은 영문 모드라 자소가 분리되거나, 반대로 cmd 단축키가 눌린 것처럼 동작하죠. HangulSync는 양쪽의 입력 소스 상태를 실시간으로 미러링해 문제를 원천 차단합니다.

## 기능

- 🔄 **실시간 양방향 동기화** — 한/영 전환이 즉시 전파
- 🌐 **자동 탐지, 무설정**
  - 같은 네트워크: **Bonjour** 자동 탐지 (근거리에서는 AWDL P2P Wi-Fi 포함)
  - 다른 네트워크: **[Tailscale](https://tailscale.com)** 이 켜져 있으면 같은 tailnet의 피어를 자동 탐지 (20초 주기)
- 🧠 **스마트 폴백** — 상대 Mac에 같은 입력기가 없어도(예: 구름입력기 vs 기본 두벌식) 언어 기준으로 알아서 매칭
- 🔁 **루프 방지** — 원격에서 적용된 변경은 재전파되지 않음
- 🖥 **메뉴바 전용** — Dock 아이콘 없이 백그라운드 상주, 로그인 시 자동 실행 지원
- 🌍 **다국어 UI** — 한국어, English, 日本語, 简体中文, 繁體中文, ไทย, Русский, Italiano
- 🎯 **원격 접속 중에만 작동** — Jump Desktop, 화면 공유, Screens, TeamViewer, AnyDesk, RustDesk 등 원격 데스크탑 앱을 쓰는 동안에만 동기화 (메뉴에서 항상 켜기로 변경 가능)
- ☁️ **인터넷 릴레이** — Tailscale 없이도 두 Mac이 한 번이라도 직접 연결된 적 있으면 이후 어디서든 자동 동기화

## 설치 (두 Mac 모두)

빌드된 `HangulSync.app`을 복사해도 됩니다.

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./build.sh
cp -R build/HangulSync.app /Applications/
open /Applications/HangulSync.app
```

Xcode Command Line Tools 필요 (`xcode-select --install`).

1. 첫 실행 시 **로컬 네트워크 접근 허용** 팝업에서 반드시 **허용**
2. 메뉴바 `⇄한` / `⇄A` 아이콘 클릭 → **로그인 시 자동 실행** 체크

## 메뉴바 아이콘

| 표시 | 의미 |
|---|---|
| `⇄한` / `⇄A` | 동기화 중 (현재 입력: 한글/영문) |
| `⏸한` / `⏸A` | 일시정지 |
| 흐린 아이콘 | 대기 중 (원격 세션 없음) |

메뉴에서 연결된 Mac 수 확인, 일시정지/재개, "원격 접속 중에만 동기화" 전환, 자동 실행 설정, 종료가 가능합니다.

## 라이선스

MIT © [dongri.me](https://dongri.me/) · AI 바이브코딩으로 만들었습니다.
