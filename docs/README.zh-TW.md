<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

一款輕量級選單列應用程式,可在多台 Mac 之間**即時同步韓語/英語輸入來源**,從根本上解決使用 **Jump Desktop**、Screens、螢幕共享等遠端桌面工具時出現的韓文字母分離(자소 분리)、輸入語言不一致與修飾鍵誤觸問題。

在一台 Mac 上切換輸入語言,所有已連接的 Mac 會立即切換到相同狀態。**無需任何設定,無需輸入 IP 位址。**

## 功能

- 🔄 **即時雙向同步** — 輸入來源變更即時傳播
- 🌐 **自動探索,零設定**
  - 同一網路:透過 **Bonjour** 自動探索(近距離支援 AWDL 點對點 Wi-Fi)
  - 不同網路:若 **[Tailscale](https://tailscale.com)** 正在執行,自動探索同一 tailnet 中的裝置(每 20 秒輪詢)
- 🧠 **智慧回退** — 對方 Mac 沒有相同輸入法時,依語言自動匹配
- 🔁 **防迴圈** — 遠端套用的變更不會被再次廣播
- 🖥 **僅選單列** — 無 Dock 圖示,背景安靜執行,支援登入時自動啟動
- 🌍 **多語言介面** — 繁體中文、English、한국어、日本語、简体中文、ไทย、Русский、Italiano
- 🎯 **僅在遠端工作階段期間運作** — 僅當使用 Jump Desktop、螢幕共享、Screens、TeamViewer、AnyDesk、RustDesk 等遠端桌面應用時同步(可在選單中改為永遠開啟)
- ☁️ **網際網路中繼** — 即使沒有 Tailscale,兩台 Mac 只要直接連線過一次,之後在任何地方都能自動同步

## 安裝(兩台 Mac 都需要)

也可以直接複製已建置的 `HangulSync.app`。

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./build.sh
cp -R build/HangulSync.app /Applications/
open /Applications/HangulSync.app
```

需要 Xcode Command Line Tools(`xcode-select --install`)。

1. 首次啟動時,請在彈出視窗中**允許區域網路存取**
2. 點選選單列 `⇄한` / `⇄A` 圖示 → 啟用**登入時自動啟動**

## 選單列

| 圖示 | 意義 |
|---|---|
| `⇄한` / `⇄A` | 同步中(目前輸入:韓語/英語) |
| `⏸한` / `⏸A` | 已暫停 |
| 變暗的圖示 | 待機(無遠端工作階段) |

## 授權

MIT © [dongri.me](https://dongri.me/) · 使用 AI 氛圍編程(vibe coding)打造。
