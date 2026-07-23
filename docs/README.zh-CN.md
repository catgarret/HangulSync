<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | [日本語](README.ja.md) | **简体中文** | [繁體中文](README.zh-TW.md) | [ไทย](README.th.md) | [Русский](README.ru.md) | [Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**解决远程桌面连接时韩文字母分离(`ㅎㅏㄴㄱㅡㄹ`)问题**的 macOS 菜单栏应用。从根源上消除 Jump Desktop、屏幕共享、Screens 等场景下本地与远程输入状态错位导致的问题。

韩语/英语输入状态在 Mac 之间自动同步。无需 IP、无需配置 —— 设备会自动发现彼此。

## 功能

- 🔄 **实时双向同步** — 输入源变更即时传播
- 🌐 **自动发现,零配置**
  - 同一网络:通过 **Bonjour** 自动发现(近距离支持 AWDL 点对点 Wi-Fi)
  - 不同网络:若 **[Tailscale](https://tailscale.com)** 正在运行,自动发现同一 tailnet 中的设备(每 20 秒轮询)
- 🧠 **智能回退** — 对方 Mac 没有相同输入法时,按语言自动匹配
- 🔁 **防循环** — 远程应用的变更不会被再次广播
- 🖥 **轻量常驻** — 通过菜单栏控制,可选择显示/隐藏程序坞图标,支持登录时自动启动
- 🌍 **多语言界面** — 简体中文、English、한국어、日本語、繁體中文、ไทย、Русский、Italiano
- 🎯 **仅在远程会话期间工作** — 仅当使用 Jump Desktop、屏幕共享、Screens、TeamViewer、AnyDesk、RustDesk 等远程桌面应用时同步(可在菜单中改为始终开启)
- ☁️ **互联网中继** — 即使没有 Tailscale,两台 Mac 只要直接连接过一次,之后在任何地方都能自动同步

## 安装(两台 Mac 都需要)

> 📦 无需编译 —— 从 [Releases](https://github.com/catgarret/HangulSync/releases/latest) 下载最新 `HangulSync.zip`,放入 `/Applications`。(首次启动:右键 → 打开)

也可以直接拷贝已构建的 `HangulSync.app`。

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./install.sh
```

需要 Xcode Command Line Tools(`xcode-select --install`)。

1. 首次启动时,请在弹窗中**允许本地网络访问**
2. 点击菜单栏 `⇄한` / `⇄A` 图标 → 启用**登录时自动启动**

## 菜单栏

| 图标 | 含义 |
|---|---|
| `⇄한` / `⇄A` | 同步中(当前输入:韩语/英语) |
| `⏸한` / `⏸A` | 已暂停 |
| 变暗的图标 | 待机(无远程会话) |

## 许可证

MIT © [dongri.me](https://dongri.me/) · 使用 AI 氛围编程(vibe coding)打造。
