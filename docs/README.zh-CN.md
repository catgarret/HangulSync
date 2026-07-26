<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md)<br>
[English](README.en.md)<br>
[日本語](README.ja.md)<br>
**简体中文**<br>
[繁體中文](README.zh-TW.md)<br>
[ไทย](README.th.md)<br>
[Русский](README.ru.md)<br>
[Italiano](README.it.md)

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

HangulSync 是一款 macOS 菜单栏应用。
它用于减少远程桌面使用过程中出现的韩文字母分离
（`ㅎㅏㄴㄱㅡㄹ`）问题。

它会同步两台 Mac 的韩语和英语输入状态。
同一网络使用 Bonjour，不同网络可以使用 Tailscale。

## 功能

- **实时双向同步**
  输入源变更即时传播
- **自动发现**
  - 同一网络:通过 **Bonjour** 自动发现(近距离支持 AWDL 点对点 Wi-Fi)
  - 不同网络：
    若 **[Tailscale](https://tailscale.com)** 正在运行，
    每 30 秒检查一次同一 tailnet 中的设备
- **按语言替代**
  对方 Mac 没有相同输入法时，使用相同语言的输入法
- **防循环**
  远程应用的变更不会被再次广播
- **轻量常驻**
  通过菜单栏控制,可选择显示/隐藏程序坞图标,支持登录时自动启动
- **多语言界面**
  简体中文、English、한국어、日本語、繁體中文、ไทย、Русский、Italiano
- **仅在远程会话期间工作**
  仅在 Jump Desktop、屏幕共享、Screens、TeamViewer、
  AnyDesk 或 RustDesk 等应用运行时同步。
  可以在菜单中改为始终开启
- **连接批准**
  新连接在用户批准前不会交换输入状态

## 安装(两台 Mac 都需要)

> 无需编译。
> 从 [Releases](https://github.com/catgarret/HangulSync/releases/latest)
> 下载最新 `HangulSync.zip`，并放入 `/Applications`。
> 首次启动时右键点击应用，然后选择 **打开**。

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

MIT © [dongri.me](https://dongri.me/)
