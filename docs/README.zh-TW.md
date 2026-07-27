<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | **繁體中文** | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

HangulSync 是一款 macOS 選單列應用程式。
它用於減少使用遠端桌面時出現的韓文字母分離
（`ㅎㅏㄴㄱㅡㄹ`）問題。

它會同步兩台 Mac 的韓語和英語輸入狀態。
同一網路使用 Bonjour，不同網路可以使用 Tailscale。

## 功能

- **即時雙向同步**
  輸入來源變更即時傳播
- **自動探索**
  - 同一網路:透過 **Bonjour** 自動探索(近距離支援 AWDL 點對點 Wi-Fi)
  - 不同網路：
    若 **[Tailscale](https://tailscale.com)** 正在執行，
    每 30 秒檢查一次同一 tailnet 中的裝置
- **依語言替代**
  對方 Mac 沒有相同輸入法時，使用相同語言的輸入法
- **防迴圈**
  遠端套用的變更不會被再次廣播
- **輕量常駐**
  透過選單列控制,可選擇顯示/隱藏 Dock 圖示,支援登入時自動啟動
- **多語言介面**
  繁體中文、English、한국어、日本語、简体中文、ไทย、Русский、Italiano
- **僅在遠端工作階段期間運作**
  僅在 Jump Desktop、螢幕共享、Screens、TeamViewer、
  AnyDesk 或 RustDesk 等應用程式執行時同步。
  可以在選單中改為永遠開啟
- **連線核准**
  新連線在使用者核准前不會交換輸入狀態
- **加密網際網路中繼**
  已配對的 Mac 在無法直接連線時透過 ntfy 交換端對端加密的狀態

## 安裝(兩台 Mac 都需要)

> 無需編譯。
> 從 [Releases](https://github.com/catgarret/HangulSync/releases/latest)
> 下載最新 `HangulSync.zip`，並放入 `/Applications`。
> 首次啟動時按右鍵，然後選擇 **打開**。

也可以直接複製已建置的 `HangulSync.app`。

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./install.sh
```

需要 Xcode Command Line Tools(`xcode-select --install`)。

1. 首次啟動時,請在彈出視窗中**允許區域網路存取**
2. 點選選單列 `⇄한` / `⇄A` 圖示 → 啟用**登入時自動啟動**

## 首次配對與 Keychain 提示

1. 在兩台 Mac 上執行 HangulSync。
2. 在任一台 Mac 的設定中按下**配對新的 Mac**。
3. 若兩台 Mac 位於不同網路，請在其中一台選擇**建立邀請碼**。
   兩分鐘內將已複製的邀請碼貼到另一台的**輸入邀請碼**。
4. 確認兩台 Mac 顯示相同的六位數代碼，然後在兩台裝置上核准。
   保持**永遠信任此裝置**開啟，日後便不需再次確認。
5. 如果 macOS 要求存取登入 Keychain，請確認應用程式名稱為 HangulSync。
   輸入目前 Mac 的登入密碼，然後選擇**永遠允許**或**允許**。

密碼只應輸入到 macOS Keychain 對話框，不要輸入到 HangulSync 視窗。
取消提示後，安全配對與網際網路中繼將無法運作。

## 選單列

| 圖示 | 意義 |
|---|---|
| `⇄한` / `⇄A` | 同步中(目前輸入:韓語/英語) |
| `⏸한` / `⏸A` | 已暫停 |
| 變暗的圖示 | 待機(無遠端工作階段) |

## 授權

MIT © [dongri.me](https://dongri.me/) · 使用 AI 氛圍程式設計製作。
