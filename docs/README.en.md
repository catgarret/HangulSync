<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | **English** | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**A macOS menu bar app that fixes Hangul jamo separation (`ㅎㅏㄴㄱㅡㄹ`) over remote desktop** — it removes the root cause: local and remote input states drifting apart in Jump Desktop, Screen Sharing, Screens and more.

The Korean/English input state syncs automatically between your Macs. No IP addresses, no setup — they find each other on their own.

## Why?

When you control a remote Mac over a remote desktop app, the local and remote input sources easily fall out of sync: you think you're typing Korean but the remote Mac is in English mode (or vice versa), producing broken jamo like `ㅎㅏㄴㄱㅡㄹ` or triggering ⌘-shortcuts instead of text. HangulSync removes the problem at the root by mirroring the input source state across machines in real time.

## Features

- 🔄 **Real-time sync** — input source changes propagate instantly in both directions
- 🌐 **Auto-discovery, no setup**
  - Same network: discovered via **Bonjour** (including AWDL peer-to-peer Wi-Fi when nearby)
  - Different networks: if **[Tailscale](https://tailscale.com)** is running, peers on your tailnet are found automatically (polled every 20 s)
- 🧠 **Smart fallback** — if the exact input method doesn't exist on the other Mac (e.g. Gureum vs. built-in 2-Set Korean), it matches by language instead
- 🔁 **Loop-safe** — remote-applied changes are never re-broadcast
- 🖥 **Lightweight** — controlled from the menu bar, optional Dock icon, launch-at-login support
- 🌍 **Localized UI** — English, 한국어, 日本語, 简体中文, 繁體中文, ไทย, Русский, Italiano
- 🎯 **Active only during remote sessions** — syncs while a remote desktop viewer (Jump Desktop, Screen Sharing, Screens, TeamViewer, AnyDesk, RustDesk…) is in use; switchable to always-on from the menu
- ☁️ **Internet relay** — even without Tailscale, once the two Macs have met directly they stay in sync from anywhere, automatically

## Install

> 📦 No build needed — grab the latest `HangulSync.zip` from [Releases](https://github.com/catgarret/HangulSync/releases/latest) and drop it into `/Applications`. (First launch: right-click → Open)

Do this on **both** Macs (a built `HangulSync.app` can also just be copied over):

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./install.sh
```

Requires Xcode Command Line Tools (`xcode-select --install`).

1. On first launch, **allow Local Network access** when prompted.
2. Click the `⇄한` / `⇄A` menu bar icon → enable **Launch at Login**.

## Menu bar

| Icon | Meaning |
|---|---|
| `⇄한` / `⇄A` | Syncing (current input: Korean / English) |
| `⏸한` / `⏸A` | Paused |
| Dimmed icon | Standby (no remote session) |

The menu shows the number of connected Macs and lets you pause/resume, toggle launch-at-login, or quit.

## License

MIT © [dongri.me](https://dongri.me/) · Built with AI vibe-coding.
