<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**解決遠端桌面連線時韓文字母分離(`ㅎㅏㄴㄱㅡㄹ`)問題**的 macOS 選單列應用程式。從根源上消除 Jump Desktop、螢幕共享、Screens 等情境下本機與遠端輸入狀態錯位導致的問題。

韓語/英語輸入狀態在 Mac 之間自動同步。無需 IP、無需設定 —— 裝置會自動發現彼此。

## 功能

- 🔄 **即時雙向同步** — 輸入來源變更即時傳播
- 🌐 **自動探索,零設定**
  - 同一網路:透過 **Bonjour** 自動探索(近距離支援 AWDL 點對點 Wi-Fi)
  - 不同網路:若 **[Tailscale](https://tailscale.com)** 正在執行,自動探索同一 tailnet 中的裝置(每 20 秒輪詢)
- 🧠 **智慧回退** — 對方 Mac 沒有相同輸入法時,依語言自動匹配
- 🔁 **防迴圈** — 遠端套用的變更不會被再次廣播
- 🖥 **輕量常駐** — 透過選單列控制,可選擇顯示/隱藏 Dock 圖示,支援登入時自動啟動
- 🌍 **多語言介面** — 繁體中文、English、한국어、日本語、简体中文、ไทย、Русский、Italiano
- 🎯 **僅在遠端工作階段期間運作** — 僅當使用 Jump Desktop、螢幕共享、Screens、TeamViewer、AnyDesk、RustDesk 等遠端桌面應用時同步(可在選單中改為永遠開啟)
- ☁️ **網際網路中繼** — 即使沒有 Tailscale,兩台 Mac 只要直接連線過一次,之後在任何地方都能自動同步

## 安裝(兩台 Mac 都需要)

> 📦 無需編譯 —— 從 [Releases](https://github.com/catgarret/HangulSync/releases/latest) 下載最新 `HangulSync.zip`,放入 `/Applications`。(首次啟動:右鍵 → 打開)

也可以直接複製已建置的 `HangulSync.app`。

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./install.sh
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
