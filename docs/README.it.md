<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [ไทย](README.th.md) | [Русский](README.ru.md) | **Italiano**

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Una piccola app per la barra dei menu che **sincronizza in tempo reale la sorgente di input coreano/inglese tra Mac**, risolvendo alla radice i problemi di Hangul "spezzato" (자소 분리), lingua di input non allineata e tasti modificatori bloccati tipici di **Jump Desktop**, Screens e altri strumenti di desktop remoto.

Cambia lingua di input su un Mac e tutti i Mac connessi cambiano all'istante. **Zero configurazione — nessun indirizzo IP da inserire.**

## Funzionalità

- 🔄 **Sincronizzazione bidirezionale in tempo reale**
- 🌐 **Rilevamento automatico, senza configurazione**
  - Stessa rete: rilevamento via **Bonjour** (con Wi-Fi P2P AWDL nelle vicinanze)
  - Reti diverse: se **[Tailscale](https://tailscale.com)** è attivo, i peer del tuo tailnet vengono trovati automaticamente (polling ogni 20 s)
- 🧠 **Fallback intelligente** — se l'altro Mac non ha lo stesso metodo di input, l'abbinamento avviene per lingua
- 🔁 **Anti-loop** — le modifiche applicate da remoto non vengono ritrasmesse
- 🖥 **Solo barra dei menu** — nessuna icona nel Dock, esecuzione silenziosa in background, avvio al login
- 🌍 **Interfaccia localizzata** — Italiano, English, 한국어, 日本語, 简体中文, 繁體中文, ไทย, Русский
- 🎯 **Attivo solo durante le sessioni remote** — sincronizza mentre usi Jump Desktop, Condivisione Schermo, Screens, TeamViewer, AnyDesk, RustDesk ecc. (attivabile sempre dal menu)
- ☁️ **Relay via internet** — anche senza Tailscale: una volta che i due Mac si sono connessi direttamente, restano sincronizzati ovunque, automaticamente

## Installazione (su entrambi i Mac)

È anche possibile copiare direttamente `HangulSync.app` già compilata.

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./build.sh
cp -R build/HangulSync.app /Applications/
open /Applications/HangulSync.app
```

Richiede gli Xcode Command Line Tools (`xcode-select --install`).

1. Al primo avvio, **consenti l'accesso alla rete locale**
2. Clicca l'icona `⇄한` / `⇄A` nella barra dei menu → attiva **Avvia al login**

## Barra dei menu

| Icona | Significato |
|---|---|
| `⇄한` / `⇄A` | Sincronizzazione attiva (input attuale: coreano/inglese) |
| `⏸한` / `⏸A` | In pausa |
| Icona attenuata | In attesa (nessuna sessione remota) |

## Licenza

MIT © [dongri.me](https://dongri.me/) · Realizzato con AI vibe-coding.
