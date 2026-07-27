<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | **English** | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

HangulSync is a macOS menu bar app that reduces separated Hangul jamo
(`ㅎㅏㄴㄱㅡㄹ`) while using remote desktop software.

It keeps the Korean and English input states aligned between two Macs.
Bonjour handles discovery on the same network.
Tailscale can be used across different networks.

## Why?

The local and remote input sources can differ during a remote desktop session.
This may produce separated jamo when one Mac uses Korean and the other uses
English.
In the opposite state, a keystroke may trigger a Command shortcut instead of
entering text.
HangulSync reduces these problems by keeping the input sources aligned.

## Features

- **Real-time sync**
  input source changes propagate instantly in both directions
- **Automatic discovery**
  - Same network: discovered via **Bonjour** (including AWDL peer-to-peer Wi-Fi when nearby)
  - Different networks:
    when **[Tailscale](https://tailscale.com)** is running,
    peers on the same tailnet are checked every 30 seconds
- **Language fallback**
  uses an input method for the same language when the exact input method is unavailable
- **Loop-safe**
  remote-applied changes are never re-broadcast
- **Lightweight**
  controlled from the menu bar, optional Dock icon, launch-at-login support
- **Localized UI**
  English, 한국어, 日本語, 简体中文, 繁體中文, ไทย, Русский, Italiano
- **Active only during remote sessions**
  syncs while a remote desktop viewer such as Jump Desktop, Screen Sharing,
  Screens, TeamViewer, AnyDesk, or RustDesk is running.
  Always-on mode is available from the menu
- **Connection approval**
  a new direct connection exchanges input state only after user approval
- **Encrypted internet relay**
  paired Macs use ntfy with end-to-end encryption when no direct connection is available

## Install

> To install without building, download the latest `HangulSync.zip` from
> [Releases](https://github.com/catgarret/HangulSync/releases/latest)
> and move it to `/Applications`.
> On first launch, right-click the app and select **Open**.

Do this on **both** Macs (a built `HangulSync.app` can also just be copied over):

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./install.sh
```

Requires Xcode Command Line Tools (`xcode-select --install`).

1. On first launch, **allow Local Network access** when prompted.
2. Click the `⇄한` / `⇄A` menu bar icon → enable **Launch at Login**.

## First pairing and Keychain prompt

1. Run HangulSync on both Macs.
2. Click **Pair New Mac** in Settings on **only one Mac**.
   Do not click it on both.
3. Select **Find Automatically** to search Bonjour and Tailscale.
4. If discovery fails, select **Create Invite** on either Mac.
   Paste the copied invite into **Enter Invite** on the other Mac within two minutes.
5. Confirm that both Macs show the same six-digit code, then approve on both.
   Keep **Always trust this device** enabled to skip confirmation in the future.
6. If macOS requests access to the login Keychain, verify that the app is HangulSync.
   Enter the current Mac login password and select **Always Allow** or **Allow**.

Enter the password only in the macOS Keychain dialog, never in a HangulSync window.
Cancelling the prompt prevents secure pairing and the internet relay from working.

## Menu bar

| Icon | Meaning |
|---|---|
| `⇄한` / `⇄A` | Syncing (current input: Korean / English) |
| `⏸한` / `⏸A` | Paused |
| Dimmed icon | Standby (no remote session) |

The menu shows the number of connected Macs and lets you pause/resume, toggle launch-at-login,
or quit.

## License

MIT © [dongri.me](https://dongri.me/) · Built with AI vibe coding.
