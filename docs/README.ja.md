<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | **日本語** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

HangulSync は、リモートデスクトップ使用中に起こるハングル字母分離
(`ㅎㅏㄴㄱㅡㄹ`)を軽減する macOS メニューバーアプリです。

2 台の Mac で韓国語と英語の入力状態を同期します。
同じネットワークでは Bonjour、別のネットワークでは Tailscale を使用できます。

## 機能

- **リアルタイム双方向同期**
  入力ソースの変更が即座に伝播
- **自動検出**
  - 同一ネットワーク: **Bonjour** で自動検出(近距離では AWDL P2P Wi-Fi も利用)
  - 別ネットワーク:
    **[Tailscale](https://tailscale.com)** が起動していれば、
    同じ tailnet のピアを 30 秒ごとに確認
- **言語による代替**
  同じ入力メソッドがない場合は同じ言語の入力メソッドを使用
- **ループ防止**
  リモートから適用された変更は再送信されません
- **軽量常駐**
  メニューバーから操作、Dock アイコンの表示/非表示を選択可、ログイン時自動起動対応
- **多言語 UI**
  日本語、English、한국어、简体中文、繁體中文、ไทย、Русский、Italiano
- **リモート接続中のみ動作**
  Jump Desktop、画面共有、Screens、TeamViewer、AnyDesk、
  RustDesk などが起動中の場合のみ同期。
  メニューから常時オンに変更可能
- **接続の承認**
  新しい接続はユーザーが承認するまで入力状態を交換しません
- **暗号化インターネットリレー**
  ペアリング済みの Mac は直接接続できない場合に ntfy でエンドツーエンド暗号化された状態を交換します

## インストール(両方の Mac に)

> ビルドは不要です。
> [Releases](https://github.com/catgarret/HangulSync/releases/latest) から最新の `HangulSync.zip`
> を取得して `/Applications` に移動します。
> 初回起動時は右クリックして **開く** を選択します。

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
