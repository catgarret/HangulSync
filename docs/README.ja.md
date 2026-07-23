<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | **日本語** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**リモートデスクトップ接続時のハングル字母分離(`ㅎㅏㄴㄱㅡㄹ`)を解決する** macOS メニューバーアプリ。Jump Desktop、画面共有、Screens などでローカルとリモートの入力状態がずれて起こる問題を根本から断ちます。

韓国語/英語の入力状態が Mac 間で自動的に同期されます。IP 入力や設定は不要 — お互いを自動で見つけて接続します。

## 機能

- 🔄 **リアルタイム双方向同期** — 入力ソースの変更が即座に伝播
- 🌐 **自動検出・設定不要**
  - 同一ネットワーク: **Bonjour** で自動検出(近距離では AWDL P2P Wi-Fi も利用)
  - 別ネットワーク: **[Tailscale](https://tailscale.com)** が起動していれば同じ tailnet のピアを自動検出(20 秒間隔)
- 🧠 **スマートフォールバック** — 相手の Mac に同じ入力メソッドがなくても言語ベースでマッチング
- 🔁 **ループ防止** — リモートから適用された変更は再送信されません
- 🖥 **軽量常駐** — メニューバーから操作、Dock アイコンの表示/非表示を選択可、ログイン時自動起動対応
- 🌍 **多言語 UI** — 日本語、English、한국어、简体中文、繁體中文、ไทย、Русский、Italiano
- 🎯 **リモート接続中のみ動作** — Jump Desktop、画面共有、Screens、TeamViewer、AnyDesk、RustDesk などの使用中のみ同期(メニューから常時オンに変更可)
- ☁️ **インターネットリレー** — Tailscale がなくても、2台の Mac が一度直接接続されれば以後どこからでも自動同期

## インストール(両方の Mac に)

> 📦 ビルド不要 — [Releases](https://github.com/catgarret/HangulSync/releases/latest) から最新の `HangulSync.zip` を取得して `/Applications` へ。(初回起動: 右クリック → 開く)

ビルド済みの `HangulSync.app` をコピーしても構いません。

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./install.sh
```

Xcode Command Line Tools が必要です(`xcode-select --install`)。

1. 初回起動時に**ローカルネットワークへのアクセスを許可**してください
2. メニューバーの `⇄한` / `⇄A` アイコン → **ログイン時に自動起動**を有効化

## メニューバー

| 表示 | 意味 |
|---|---|
| `⇄한` / `⇄A` | 同期中(現在の入力: 韓国語/英語) |
| `⏸한` / `⏸A` | 一時停止中 |
| 薄いアイコン | 待機中(リモートセッションなし) |

## ライセンス

MIT © [dongri.me](https://dongri.me/) · AIバイブコーディングで作りました。
