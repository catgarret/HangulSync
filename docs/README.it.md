<p align="center">
  <img src="../assets/icon-256.png" width="128" alt="HangulSync">
</p>

<h1 align="center">HangulSync</h1>

[한국어](../README.md) | [English](README.en.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [ไทย](README.th.md) | [Русский](README.ru.md) | **Italiano**

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**App per la barra dei menu di macOS che risolve i jamo separati dell'Hangul (`ㅎㅏㄴㄱㅡㄹ`) nel desktop remoto** — elimina la causa alla radice: lo scollamento dello stato di input tra Mac locale e remoto in Jump Desktop, Condivisione Schermo, Screens e altri.

Lo stato di input coreano/inglese si sincronizza automaticamente tra i Mac. Nessun IP, nessuna configurazione: si trovano da soli.

## Funzionalità

- 🔄 **Sincronizzazione bidirezionale in tempo reale**
- 🌐 **Rilevamento automatico, senza configurazione**
  - Stessa rete: rilevamento via **Bonjour** (con Wi-Fi P2P AWDL nelle vicinanze)
  - Reti diverse: se **[Tailscale](https://tailscale.com)** è attivo, i peer del tuo tailnet vengono trovati automaticamente (polling ogni 20 s)
- 🧠 **Fallback intelligente** — se l'altro Mac non ha lo stesso metodo di input, l'abbinamento avviene per lingua
- 🔁 **Anti-loop** — le modifiche applicate da remoto non vengono ritrasmesse
- 🖥 **Leggera** — controllo dalla barra dei menu, icona nel Dock opzionale, avvio al login
- 🌍 **Interfaccia localizzata** — Italiano, English, 한국어, 日本語, 简体中文, 繁體中文, ไทย, Русский
- 🎯 **Attivo solo durante le sessioni remote** — sincronizza mentre usi Jump Desktop, Condivisione Schermo, Screens, TeamViewer, AnyDesk, RustDesk ecc. (attivabile sempre dal menu)
- ☁️ **Relay via internet** — anche senza Tailscale: una volta che i due Mac si sono connessi direttamente, restano sincronizzati ovunque, automaticamente

## Installazione (su entrambi i Mac)

> 📦 Nessuna build necessaria — scarica l'ultimo `HangulSync.zip` da [Releases](https://github.com/catgarret/HangulSync/releases/latest) e mettilo in `/Applications`. (Primo avvio: clic destro → Apri)

È anche possibile copiare direttamente `HangulSync.app` già compilata.

```bash
git clone https://github.com/catgarret/HangulSync.git
cd HangulSync
./install.sh
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
