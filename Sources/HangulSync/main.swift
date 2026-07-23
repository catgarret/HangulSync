import AppKit
import ServiceManagement

/// UX 구조
/// - 첫 실행: Dock에 표시 + 설정 창 자동 오픈
/// - Dock 아이콘 클릭 → 설정 창 / 메뉴바 아이콘 → 빠른 제어
/// - 설정 창: 상태 카드 + 옵션 카드(토글 스위치) — 시스템 설정 스타일
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let engine = SyncEngine()

    // MARK: 메뉴바 메뉴 (빠른 제어만)
    private let peerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleSync), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "", action: #selector(showSettings), keyEquivalent: ",")

    // MARK: 설정 창
    private var settingsWindow: NSWindow?
    private var settingsStack: NSStackView?
    private let statusDot = NSTextField(labelWithString: "●")
    private let statusText = NSTextField(wrappingLabelWithString: "")
    private let peersText = NSTextField(labelWithString: "")
    private var peersStack: NSStackView?
    private lazy var loginSwitch = makeSwitch(#selector(toggleLogin))
    private lazy var remoteOnlySwitch = makeSwitch(#selector(toggleRemoteOnly))
    private lazy var dockSwitch = makeSwitch(#selector(toggleDock))

    private let contentWidth: CGFloat = 360

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

        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
            showSettings()
        }
        NSLog("HangulSync: 준비 완료")
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

    // MARK: - 설정 창 (시스템 설정 스타일)

    @objc private func showSettings() {
        if settingsWindow == nil { buildSettingsWindow() }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func makeSwitch(_ action: Selector) -> NSSwitch {
        let s = NSSwitch()
        s.target = self
        s.action = action
        return s
    }

    /// 라운드 카드 (시스템 설정의 그룹 박스 느낌)
    private func card(_ inner: NSView) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 10
        box.borderWidth = 1
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.5)
        box.fillColor = .controlBackgroundColor
        box.contentViewMargins = .zero
        box.contentView = inner
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        if let content = box.contentView {
            inner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                inner.topAnchor.constraint(equalTo: content.topAnchor),
                inner.bottomAnchor.constraint(equalTo: content.bottomAnchor),
                inner.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                inner.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            ])
        }
        return box
    }

    private func hairline() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    /// 옵션 행: 제목(+부제) 왼쪽, 토글 스위치 오른쪽
    private func settingRow(title: String, subtitle: String? = nil, control: NSView) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        var texts: [NSView] = [titleLabel]
        if let subtitle {
            let sub = NSTextField(wrappingLabelWithString: subtitle)
            sub.font = .systemFont(ofSize: 11)
            sub.textColor = .secondaryLabelColor
            sub.preferredMaxLayoutWidth = contentWidth - 100
            texts.append(sub)
        }
        let textStack = NSStackView(views: texts)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [textStack, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        return row
    }

    private func buildSettingsWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentWidth + 40, height: 100),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        win.title = "HangulSync"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false

        // 헤더: 아이콘 + 이름 + 한 줄 설명
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let titleLabel = NSTextField(labelWithString: "HangulSync")
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        let tagline = NSTextField(wrappingLabelWithString: L10n.t(.tagline))
        tagline.font = .systemFont(ofSize: 12)
        tagline.textColor = .secondaryLabelColor
        tagline.preferredMaxLayoutWidth = contentWidth - 70

        let titleStack = NSStackView(views: [titleLabel, tagline])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 3

        let header = NSStackView(views: [iconView, titleStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        // 상태 카드
        statusDot.font = .systemFont(ofSize: 10)
        statusText.font = .systemFont(ofSize: 13, weight: .medium)
        statusText.preferredMaxLayoutWidth = contentWidth - 60
        let statusRow = NSStackView(views: [statusDot, statusText])
        statusRow.orientation = .horizontal
        statusRow.alignment = .firstBaseline
        statusRow.spacing = 7
        statusRow.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 10, right: 14)

        peersText.font = .systemFont(ofSize: 11, weight: .semibold)
        peersText.textColor = .secondaryLabelColor
        let peersHeader = NSStackView(views: [peersText])
        peersHeader.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 0, right: 14)

        let peers = NSStackView(views: [])
        peers.orientation = .vertical
        peers.alignment = .leading
        peers.spacing = 6
        peers.edgeInsets = NSEdgeInsets(top: 6, left: 14, bottom: 12, right: 14)
        peersStack = peers

        let statusInner = NSStackView(views: [statusRow, hairline(), peersHeader, peers])
        statusInner.orientation = .vertical
        statusInner.alignment = .leading
        statusInner.spacing = 0
        statusRow.widthAnchor.constraint(equalTo: statusInner.widthAnchor).isActive = true
        peersHeader.widthAnchor.constraint(equalTo: statusInner.widthAnchor).isActive = true
        peers.widthAnchor.constraint(equalTo: statusInner.widthAnchor).isActive = true

        // 옵션 카드
        let row1 = settingRow(title: L10n.t(.launchAtLogin), control: loginSwitch)
        let row2 = settingRow(title: L10n.t(.onlyDuringRemote), control: remoteOnlySwitch)
        let row3 = settingRow(title: L10n.t(.showInDock), subtitle: L10n.t(.dockHint), control: dockSwitch)
        let optionsInner = NSStackView(views: [row1, hairline(), row2, hairline(), row3])
        optionsInner.orientation = .vertical
        optionsInner.alignment = .leading
        optionsInner.spacing = 0
        for row in [row1, row2, row3] {
            row.widthAnchor.constraint(equalTo: optionsInner.widthAnchor).isActive = true
        }

        // 푸터: 버전 · GitHub · dongri.me
        func linkButton(_ title: String, action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.isBordered = false
            b.contentTintColor = .secondaryLabelColor
            b.font = .systemFont(ofSize: 11)
            return b
        }
        func dot() -> NSTextField {
            let d = NSTextField(labelWithString: "·")
            d.font = .systemFont(ofSize: 11)
            d.textColor = .tertiaryLabelColor
            return d
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "v\(version)")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .tertiaryLabelColor
        let footer = NSStackView(views: [
            versionLabel, dot(),
            linkButton("GitHub", action: #selector(openGitHub)), dot(),
            linkButton("dongri.me", action: #selector(openHomepage)),
        ])
        footer.orientation = .horizontal
        footer.spacing = 5

        // 전체 레이아웃
        let stack = NSStackView(views: [header, card(statusInner), card(optionsInner), footer])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 40, left: 20, bottom: 18, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: contentWidth + 40).isActive = true

        win.contentView = stack
        win.setContentSize(stack.fittingSize)
        win.center()
        settingsStack = stack
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
                img.isTemplate = true // 다크/라이트 메뉴바 자동 색반전 (필수)
                img.size = NSSize(width: 18, height: 18)
                button.image = img
                button.imagePosition = .imageOnly
                button.title = ""
            } else {
                button.image = nil
                button.title = engine.enabled ? "⇄\(korean ? "한" : "A")" : "⏸"
            }
            button.appearsDisabled = !engine.syncAllowed
            button.toolTip = "HangulSync — \(L10n.connectedMacs(engine.readyPeerCount))"
        }

        // 메뉴
        peerItem.title = L10n.connectedMacs(engine.readyPeerCount)
        toggleItem.title = engine.enabled ? L10n.t(.pauseSync) : L10n.t(.resumeSync)
        settingsItem.title = L10n.t(.settings)

        // 상태: 회색=일시정지 / 빨강=연결 안 됨 / 초록=작동 중 / 주황=대기 중
        if !engine.enabled {
            statusDot.textColor = .systemGray
            statusText.stringValue = L10n.t(.statusPaused)
        } else if engine.readyPeerCount == 0 {
            statusDot.textColor = .systemRed
            statusText.stringValue = L10n.t(.statusNotConnected)
        } else if engine.syncAllowed {
            statusDot.textColor = .systemGreen
            statusText.stringValue = L10n.t(.statusSyncing)
        } else {
            statusDot.textColor = .systemOrange
            statusText.stringValue = L10n.t(.statusStandby)
        }
        peersText.stringValue = L10n.connectedMacs(engine.readyPeerCount)

        // 피어 목록 갱신: 이름 왼쪽, 연결 경로 오른쪽
        if let peers = peersStack {
            peers.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let list = engine.peerInfo
            if list.isEmpty {
                let empty = NSTextField(labelWithString: L10n.t(.noPeers))
                empty.font = .systemFont(ofSize: 12)
                empty.textColor = .tertiaryLabelColor
                peers.addArrangedSubview(empty)
            } else {
                for peer in list {
                    let name = NSTextField(labelWithString: peer.name)
                    name.font = .systemFont(ofSize: 13)
                    name.setContentHuggingPriority(.defaultLow, for: .horizontal)
                    let via = NSTextField(labelWithString: peer.via)
                    via.font = .systemFont(ofSize: 12)
                    via.textColor = .secondaryLabelColor
                    let row = NSStackView(views: [name, via])
                    row.orientation = .horizontal
                    row.spacing = 8
                    peers.addArrangedSubview(row)
                    row.widthAnchor.constraint(equalTo: peers.widthAnchor, constant: -28).isActive = true
                }
            }
        }

        remoteOnlySwitch.state = engine.onlyDuringRemote ? .on : .off
        dockSwitch.state = showInDock ? .on : .off
        if #available(macOS 13.0, *) {
            loginSwitch.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }

        // 목록 길이에 맞춰 창 높이 조절
        if let win = settingsWindow, win.isVisible, let stack = settingsStack {
            let size = stack.fittingSize
            if let content = win.contentView, abs(content.frame.height - size.height) > 1 {
                win.setContentSize(size)
            }
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
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        refresh()
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/catgarret/HangulSync")!)
    }

    @objc private func openHomepage() {
        NSWorkspace.shared.open(URL(string: "https://dongri.me/")!)
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
