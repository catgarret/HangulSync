import AppKit
import ServiceManagement

/// 라운드 카드 — 테두리 없이 은은한 채움색 (라이트/다크 자동 적응)
final class CardView: NSView {
    init(content: NSView) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    override func updateLayer() {
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.055).cgColor
    }
}

/// UX 구조
/// - 첫 실행: Dock에 표시 + 설정 창 자동 오픈
/// - Dock 아이콘 클릭 → 설정 창 / 메뉴바 아이콘 → 빠른 제어
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {

    private var statusItem: NSStatusItem!
    private let engine = SyncEngine()
    private let updateChecker = UpdateChecker()

    // MARK: 메뉴바 메뉴 (빠른 제어만)
    private let peerItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let toggleItem = NSMenuItem(title: "", action: #selector(toggleSync), keyEquivalent: "")
    private let settingsItem = NSMenuItem(title: "", action: #selector(showSettings), keyEquivalent: ",")
    private let updateItem = NSMenuItem(title: "", action: #selector(openUpdate), keyEquivalent: "")
    private var updateButton: NSButton?

    // MARK: 설정 창
    private var settingsWindow: NSWindow?
    private var settingsStack: NSStackView?
    private let statusDot = NSTextField(labelWithString: "●")
    private let statusText = NSTextField(labelWithString: "")
    private let statusSub = NSTextField(wrappingLabelWithString: "")
    private var peersSection: NSStackView?
    private lazy var loginSwitch = makeSwitch(#selector(toggleLogin))
    private lazy var remoteOnlySwitch = makeSwitch(#selector(toggleRemoteOnly))
    private lazy var dockSwitch = makeSwitch(#selector(toggleDock))

    private let contentWidth: CGFloat = 360
    private let cardPadding: CGFloat = 16

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
        updateChecker.onUpdateFound = { [weak self] in self?.refresh() }
        updateChecker.start()
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

    /// 창을 닫으면 창·뷰 계층을 통째로 해제해 메모리 반환 (다시 열면 재생성)
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === settingsWindow else { return }
        settingsWindow = nil
        settingsStack = nil
        peersSection = nil
        updateButton = nil
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        peerItem.isEnabled = false
        toggleItem.target = self
        settingsItem.target = self
        updateItem.target = self
        updateItem.isHidden = true
        menu.addItem(peerItem)
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(settingsItem)
        menu.addItem(updateItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.t(.quit), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        refresh()
    }

    // MARK: - 설정 창

    @objc private func showSettings() {
        let firstBuild = settingsWindow == nil
        if firstBuild { buildSettingsWindow() }
        refresh() // 텍스트 채운 뒤 높이 재계산까지 수행됨
        if firstBuild { settingsWindow?.center() } // 최종 크기로 화면 중앙 배치
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func makeSwitch(_ action: Selector) -> NSSwitch {
        let s = NSSwitch()
        s.target = self
        s.action = action
        return s
    }

    /// 세로 스택 → 카드.
    /// 패딩 규칙(고정): 카드 상하 14 · 좌우 16(행이 자체 보유) · 행 간격 = gap
    private func makeCard(_ rows: [NSView], gap: CGFloat = 14) -> CardView {
        let inner = NSStackView(views: rows)
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = gap
        inner.edgeInsets = NSEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        for row in rows {
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        }
        let card = CardView(content: inner)
        card.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true
        return card
    }

    /// 옵션 행: 텍스트는 왼쪽 끝, 스위치는 오른쪽 끝 (gravity 고정)
    private func settingRow(title: String, subtitle: String? = nil, control: NSView) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13)
        var texts: [NSView] = [titleLabel]
        if let subtitle {
            let sub = NSTextField(wrappingLabelWithString: subtitle)
            sub.font = .systemFont(ofSize: 11)
            sub.textColor = .secondaryLabelColor
            sub.preferredMaxLayoutWidth = contentWidth - cardPadding * 2 - 66 // 스위치 영역 제외 가용 폭 전부 사용
            texts.append(sub)
        }
        let textStack = NSStackView(views: texts)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 0, left: cardPadding, bottom: 0, right: cardPadding)
        row.addView(textStack, in: .leading)
        row.addView(control, in: .trailing)
        return row
    }

    private func buildSettingsWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentWidth + 48, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        win.title = "HangulSync"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.delegate = self

        // 헤더: 아이콘 + 이름 + 한 줄 설명
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 56).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let titleLabel = NSTextField(labelWithString: "HangulSync")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        let tagline = NSTextField(wrappingLabelWithString: L10n.t(.tagline))
        tagline.font = .systemFont(ofSize: 11.5)
        tagline.textColor = .secondaryLabelColor
        tagline.preferredMaxLayoutWidth = contentWidth - 70 // 아이콘·간격 제외 가용 폭

        let titleStack = NSStackView(views: [titleLabel, tagline])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 3

        let header = NSStackView(views: [iconView, titleStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14
        header.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalToConstant: contentWidth).isActive = true

        // 상태 카드: ● 제목 (굵게) / 아랫줄 설명 (회색) + (연결 시) 피어 목록
        statusDot.font = .systemFont(ofSize: 9)
        statusText.font = .systemFont(ofSize: 13, weight: .semibold)
        statusSub.font = .systemFont(ofSize: 12)
        statusSub.textColor = .secondaryLabelColor
        statusSub.preferredMaxLayoutWidth = contentWidth - cardPadding * 2 - 17

        let statusTexts = NSStackView(views: [statusText, statusSub])
        statusTexts.orientation = .vertical
        statusTexts.alignment = .leading
        statusTexts.spacing = 3

        let statusRow = NSStackView()
        statusRow.orientation = .horizontal
        statusRow.alignment = .firstBaseline
        statusRow.spacing = 8
        statusRow.edgeInsets = NSEdgeInsets(top: 0, left: cardPadding, bottom: 0, right: cardPadding)
        statusRow.addView(statusDot, in: .leading)
        statusRow.addView(statusTexts, in: .leading)

        let peers = NSStackView(views: [])
        peers.orientation = .vertical
        peers.alignment = .leading
        peers.spacing = 8
        peers.edgeInsets = NSEdgeInsets(top: 0, left: cardPadding + 17, bottom: 0, right: cardPadding)
        peersSection = peers

        let statusCard = makeCard([statusRow, peers], gap: 10)

        // 옵션 카드 (구분선 없이 여백으로 구분)
        let optionsCard = makeCard([
            settingRow(title: L10n.t(.launchAtLogin), control: loginSwitch),
            settingRow(title: L10n.t(.onlyDuringRemote), control: remoteOnlySwitch),
            settingRow(title: L10n.t(.showInDock), subtitle: L10n.t(.dockHint), control: dockSwitch),
        ], gap: 14)

        // 페어링 액션: 주요 동작과 파괴적 동작을 한 행에 분리
        let pairButton = NSButton(
            title: L10n.t(.pairNewMac),
            target: self,
            action: #selector(startPairing)
        )
        pairButton.bezelStyle = .rounded
        pairButton.controlSize = .large

        let resetButton = NSButton(
            title: L10n.t(.resetPairings),
            target: self,
            action: #selector(resetPairings)
        )
        resetButton.isBordered = false
        resetButton.contentTintColor = .systemRed
        resetButton.font = .systemFont(ofSize: 12)

        let pairingRow = NSStackView()
        pairingRow.orientation = .horizontal
        pairingRow.alignment = .centerY
        pairingRow.spacing = 12
        pairingRow.edgeInsets = NSEdgeInsets(
            top: 0,
            left: cardPadding,
            bottom: 0,
            right: cardPadding
        )
        pairingRow.addView(pairButton, in: .leading)
        pairingRow.addView(resetButton, in: .trailing)
        let pairingCard = makeCard([pairingRow])

        // 푸터: 버전 · GitHub · dongri.me
        func linkButton(_ title: String, action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.isBordered = false
            b.contentTintColor = .tertiaryLabelColor
            b.font = .systemFont(ofSize: 11)
            return b
        }
        func dot() -> NSTextField {
            let d = NSTextField(labelWithString: "·")
            d.font = .systemFont(ofSize: 11)
            d.textColor = .quaternaryLabelColor
            return d
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let versionLabel = NSTextField(labelWithString: "v\(version)")
        versionLabel.font = .systemFont(ofSize: 11)
        versionLabel.textColor = .quaternaryLabelColor
        let update = linkButton("", action: #selector(openUpdate))
        update.contentTintColor = .systemOrange
        update.isHidden = true
        updateButton = update
        let footer = NSStackView(views: [
            versionLabel, dot(),
            linkButton("GitHub", action: #selector(openGitHub)), dot(),
            linkButton("dongri.me", action: #selector(openHomepage)),
        ])
        footer.orientation = .horizontal
        footer.spacing = 6

        // 전체 레이아웃
        let stack = NSStackView(views: [
            header,
            statusCard,
            optionsCard,
            pairingCard,
            update,
            footer,
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.setCustomSpacing(20, after: header)
        stack.setCustomSpacing(12, after: statusCard)
        stack.setCustomSpacing(12, after: optionsCard)
        stack.setCustomSpacing(12, after: pairingCard)
        stack.setCustomSpacing(8, after: update)
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 24, bottom: 20, right: 24)

        let container = NSView()
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        win.contentView = container
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
        // 문자열의 " — " 앞은 제목(굵게), 뒤는 설명(회색)으로 두 줄 표시
        let setStatus: (L10n.Key, NSColor) -> Void = { [weak self] key, color in
            guard let self else { return }
            self.statusDot.textColor = color
            let parts = L10n.t(key).components(separatedBy: " — ")
            self.statusText.stringValue = parts[0]
            let sub = parts.dropFirst().joined(separator: " — ")
            self.statusSub.stringValue = sub
            self.statusSub.isHidden = sub.isEmpty
        }
        if !engine.enabled {
            setStatus(.statusPaused, .systemGray)
        } else if engine.readyPeerCount == 0 {
            setStatus(.statusNotConnected, .systemRed)
        } else if engine.syncAllowed {
            setStatus(.statusSyncing, .systemGreen)
        } else {
            setStatus(.statusStandby, .systemOrange)
        }

        // 피어 목록: 연결된 Mac이 있을 때만 상태 아래에 표시 (이름 왼쪽 · 경로 오른쪽)
        if let peers = peersSection {
            peers.arrangedSubviews.forEach { $0.removeFromSuperview() }
            let list = engine.peerInfo
            peers.isHidden = list.isEmpty
            for peer in list {
                let name = NSTextField(labelWithString: peer.name)
                name.font = .systemFont(ofSize: 13)
                let via = NSTextField(labelWithString: peer.via)
                via.font = .systemFont(ofSize: 12)
                via.textColor = .secondaryLabelColor
                let row = NSStackView()
                row.orientation = .horizontal
                row.alignment = .centerY
                row.spacing = 12
                row.addView(name, in: .leading)
                row.addView(via, in: .trailing)
                let forget = NSButton(
                    title: L10n.t(.forgetDevice),
                    target: self,
                    action: #selector(forgetPeer(_:))
                )
                forget.identifier = NSUserInterfaceItemIdentifier(peer.id)
                forget.bezelStyle = .inline
                row.addView(forget, in: .trailing)
                peers.addArrangedSubview(row)
                row.widthAnchor.constraint(equalTo: peers.widthAnchor, constant: -(cardPadding * 2 + 17)).isActive = true
            }
        }

        remoteOnlySwitch.state = engine.onlyDuringRemote ? .on : .off
        dockSwitch.state = showInDock ? .on : .off
        if #available(macOS 13.0, *) {
            loginSwitch.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }

        // 새 버전 알림 (메뉴 + 설정 창 푸터)
        if updateChecker.updateAvailable, let latest = updateChecker.latestVersion {
            let title = String(format: L10n.t(.updateAvailable), "v\(latest)")
            updateItem.title = title
            updateItem.isHidden = false
            updateButton?.title = title
            updateButton?.isHidden = false
        } else {
            updateItem.isHidden = true
            updateButton?.isHidden = true
        }

        // 내용(상태 2줄, 피어 목록 등)에 맞춰 창 높이를 항상 재계산 — 여백 일정 유지
        if let win = settingsWindow, let stack = settingsStack {
            stack.layoutSubtreeIfNeeded()
            let size = stack.fittingSize
            if let content = win.contentView, abs(content.frame.height - size.height) > 1 {
                let keepTopLeft = win.frame.origin
                let delta = size.height - content.frame.height
                win.setContentSize(size)
                // 위쪽 기준 고정 (창이 아래로 늘어나게)
                win.setFrameOrigin(NSPoint(x: keepTopLeft.x, y: keepTopLeft.y - delta))
            }
        }
    }

    // MARK: - 액션

    @objc private func toggleSync() {
        engine.enabled.toggle()
        refresh()
    }

    @objc private func startPairing() {
        engine.beginPairingMode()
    }

    @objc private func forgetPeer(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        engine.forgetPeer(id: id)
    }

    @objc private func resetPairings() {
        engine.resetPairings()
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

    @objc private func openUpdate() {
        NSWorkspace.shared.open(updateChecker.latestURL ?? UpdateChecker.releasesPage)
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
