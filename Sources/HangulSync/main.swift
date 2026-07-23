import AppKit
import ServiceManagement

/// 메뉴바 전용 앱 (Dock 아이콘 없음, 백그라운드 상주)
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let engine = SyncEngine()

    private let peerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleSync), keyEquivalent: "")
    private let remoteOnlyItem = NSMenuItem(title: "", action: #selector(toggleRemoteOnly), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.delegate = self
        peerItem.isEnabled = false
        toggleItem.target = self
        remoteOnlyItem.target = self
        loginItem.target = self
        menu.addItem(peerItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(remoteOnlyItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L10n.t(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu

        engine.onStateChange = { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
        engine.start()
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    private func refresh() {
        let korean = InputSourceManager.current()?.isKorean == true
        if let button = statusItem.button {
            let imageName = engine.enabled
                ? (korean ? "MenubarKoTemplate" : "MenubarEnTemplate")
                : "MenubarPauseTemplate"
            if let img = NSImage(named: imageName) {
                img.size = NSSize(width: 18, height: 18)
                button.image = img
                button.title = ""
            } else {
                // 아이콘 리소스가 없을 때(예: swift run 직접 실행) 텍스트 폴백
                button.image = nil
                button.title = engine.enabled ? "⇄\(korean ? "한" : "A")" : "⏸"
            }
            button.appearsDisabled = !engine.syncAllowed // 대기(원격 세션 없음)·일시정지 시 흐리게
            button.toolTip = "HangulSync — \(L10n.connectedMacs(engine.readyPeerCount))"
        }
        peerItem.title = L10n.connectedMacs(engine.readyPeerCount)
        toggleItem.title = engine.enabled ? L10n.t(.pauseSync) : L10n.t(.resumeSync)
        remoteOnlyItem.title = L10n.t(.onlyDuringRemote)
        remoteOnlyItem.state = engine.onlyDuringRemote ? .on : .off
        if #available(macOS 13.0, *) {
            loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }
    }

    @objc private func toggleSync() {
        engine.enabled.toggle()
        refresh()
    }

    @objc private func toggleRemoteOnly() {
        engine.onlyDuringRemote.toggle()
        refresh()
    }

    @objc private func toggleLogin() {
        guard #available(macOS 13.0, *) else { return }
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = L10n.t(.loginErrorTitle)
            alert.informativeText = "\(L10n.t(.loginErrorBody))\n(\(error.localizedDescription))"
            alert.runModal()
        }
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // 메뉴바 전용
app.run()
