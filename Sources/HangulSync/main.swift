import AppKit
import ServiceManagement

/// 메뉴바 전용 앱 (Dock 아이콘 없음, 백그라운드 상주)
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let engine = SyncEngine()

    private let peerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleSync), keyEquivalent: "")
    private let remoteOnlyItem = NSMenuItem(title: "", action: #selector(toggleRemoteOnly), keyEquivalent: "")
    private let dockItem = NSMenuItem(title: "", action: #selector(toggleDock), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "", action: #selector(toggleLogin), keyEquivalent: "")

    /// Dock 아이콘 표시 여부 (기본: 표시)
    private var showInDock: Bool {
        get {
            UserDefaults.standard.object(forKey: "ShowInDock") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "ShowInDock")
        }
        set { UserDefaults.standard.set(newValue, forKey: "ShowInDock") }
    }

    private func applyDockPolicy() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("HangulSync: 실행 시작")
        applyDockPolicy()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true

        let menu = NSMenu()
        menu.delegate = self
        peerItem.isEnabled = false
        toggleItem.target = self
        remoteOnlyItem.target = self
        dockItem.target = self
        loginItem.target = self
        menu.addItem(peerItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(remoteOnlyItem)
        menu.addItem(.separator())
        menu.addItem(dockItem)
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
        NSLog("HangulSync: 메뉴바 아이콘 설치 완료 (image=\(statusItem.button?.image != nil))")
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
            if let img = NSImage(named: imageName), img.size.width > 0 {
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
        dockItem.title = L10n.t(.showInDock)
        dockItem.state = showInDock ? .on : .off
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

    @objc private func toggleDock() {
        showInDock.toggle()
        applyDockPolicy()
        if showInDock { NSApp.activate(ignoringOtherApps: true) }
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
// Dock 표시 여부는 설정에 따라 applicationDidFinishLaunching에서 결정
app.run()
