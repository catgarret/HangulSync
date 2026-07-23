import AppKit
import ServiceManagement

/// UX 구조
/// - 첫 실행: Dock에 표시 + 설정 창 자동 오픈 (상태와 옵션이 한눈에 보임)
/// - Dock 아이콘 클릭 → 설정 창
/// - 메뉴바 아이콘 → 빠른 제어 (상태 / 일시정지 / 설정… / 종료)
/// - 설정 창: 상태 문장 + 체크박스 3개 (부팅 시 자동 시작 / 원격 중에만 동기화 / Dock 표시)
/// - 창을 닫아도 앱은 백그라운드(메뉴바)에서 계속 동작
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let engine = SyncEngine()

    // MARK: 메뉴바 메뉴 (빠른 제어만)
    private let peerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleSync), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "", action: #selector(showSettings), keyEquivalent: ",")

    // MARK: 설정 창 컨트롤
    private var settingsWindow: NSWindow?
    private let statusDot = NSTextField(labelWithString: "●")
    private let statusText = NSTextField(labelWithString: "")
    private let peersText = NSTextField(labelWithString: "")
    private lazy var loginCheck = NSButton(checkboxWithTitle: L10n.t(.launchAtLogin), target: self, action: #selector(toggleLogin))
    private lazy var remoteOnlyCheck = NSButton(checkboxWithTitle: L10n.t(.onlyDuringRemote), target: self, action: #selector(toggleRemoteOnly))
    private lazy var dockCheck = NSButton(checkboxWithTitle: L10n.t(.showInDock), target: self, action: #selector(toggleDock))

    /// Dock 아이콘 표시 여부 (기본: 표시)
    private var showInDock: Bool {
        get {
            UserDefaults.standard.object(forKey: "ShowInDock") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "ShowInDock")
        }
        set { UserDefaults.standard.set(newValue, forKey: "ShowInDock") }
    }

    // MARK: - 시작

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("HangulSync: 실행 시작")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        buildMenu()

        engine.onStateChange = { [weak self] in
            DispatchQueue.main.async { self?.refresh() }
        }
        engine.start()
        refresh()

        // 첫 실행이면 설정 창을 열어 앱 존재와 옵션을 보여줌
        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            showSettings()
        }
        NSLog("HangulSync: 준비 완료 (menubar image=\(statusItem.button?.image != nil))")
    }

    /// Dock 아이콘 클릭 → 설정 창
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showSettings() }
        return true
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        peerItem.isEnabled = false
        toggleItem.target = self
        settingsItem.target = self
        menu.addItem(peerItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.t(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    // MARK: - 설정 창

    @objc private func showSettings() {
        if settingsWindow == nil { buildSettingsWindow() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func buildSettingsWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 100),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "HangulSync"
        win.isReleasedWhenClosed = false

        // 헤더: 아이콘 + 이름 + 한 줄 설명
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let titleLabel = NSTextField(labelWithString: "HangulSync")
        titleLabel.font = .boldSystemFont(ofSize: 17)
        let tagline = NSTextField(wrappingLabelWithString: L10n.t(.tagline))
        tagline.font = .systemFont(ofSize: 12)
        tagline.textColor = .secondaryLabelColor

        let titleStack = NSStackView(views: [titleLabel, tagline])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 3

        let header = NSStackView(views: [iconView, titleStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        // 상태
        statusText.font = .systemFont(ofSize: 12, weight: .medium)
        peersText.font = .systemFont(ofSize: 12)
        peersText.textColor = .secondaryLabelColor
        let statusRow = NSStackView(views: [statusDot, statusText])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6

        // 안내
        let hint = NSTextField(wrappingLabelWithString: L10n.t(.dockHint))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor

        func separator() -> NSBox {
            let box = NSBox()
            box.boxType = .separator
            return box
        }

        let stack = NSStackView(views: [
            header,
            separator(),
            statusRow,
            peersText,
            separator(),
            loginCheck,
            remoteOnlyCheck,
            dockCheck,
            hint,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 440).isActive = true

        win.contentView = stack
        win.setContentSize(stack.fittingSize)
        win.center()
        settingsWindow = win
    }

    // MARK: - 상태 반영 (메뉴바 + 설정 창 동시 갱신)

    private func refresh() {
        let korean = InputSourceManager.current()?.isKorean == true

        // 메뉴바 아이콘
        if let button = statusItem.button {
            let imageName = engine.enabled
                ? (korean ? "MenubarKoTemplate" : "MenubarEnTemplate")
                : "MenubarPauseTemplate"
            if let img = NSImage(named: imageName), img.size.width > 0 {
                img.size = NSSize(width: 18, height: 18)
                button.image = img
                button.title = ""
            } else {
                button.image = nil
                button.title = engine.enabled ? "⇄\(korean ? "한" : "A")" : "⏸"
            }
            button.appearsDisabled = !engine.syncAllowed // 대기·일시정지 시 흐리게
            button.toolTip = "HangulSync — \(L10n.connectedMacs(engine.readyPeerCount))"
        }

        // 메뉴
        peerItem.title = L10n.connectedMacs(engine.readyPeerCount)
        toggleItem.title = engine.enabled ? L10n.t(.pauseSync) : L10n.t(.resumeSync)
        settingsItem.title = L10n.t(.settings)

        // 설정 창
        if !engine.enabled {
            statusDot.textColor = .systemGray
            statusText.stringValue = L10n.t(.statusPaused)
        } else if engine.syncAllowed {
            statusDot.textColor = .systemGreen
            statusText.stringValue = L10n.t(.statusSyncing)
        } else {
            statusDot.textColor = .systemOrange
            statusText.stringValue = L10n.t(.statusStandby)
        }
        peersText.stringValue = L10n.connectedMacs(engine.readyPeerCount)
        remoteOnlyCheck.state = engine.onlyDuringRemote ? .on : .off
        dockCheck.state = showInDock ? .on : .off
        if #available(macOS 13.0, *) {
            loginCheck.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }
    }

    // MARK: - 액션

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
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        // 정책 전환 시 설정 창이 뒤로 가지 않게 유지
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
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
app.run()
