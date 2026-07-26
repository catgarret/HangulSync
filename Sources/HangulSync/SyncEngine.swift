import Foundation
import AppKit
import Carbon
import Network

/// 입력 소스 변경 감지 → 피어 전파, 피어 메시지 수신 → 로컬 적용.
/// 피어 경로: ① Bonjour(같은 네트워크/AWDL) ② Tailscale
/// 기본적으로 원격 데스크탑 뷰어가 사용 중일 때만 동기화가 활성화된다.
final class SyncEngine {

    static let serviceType = "_hangulsync._tcp"
    static let port: UInt16 = 47820

    /// 전면(frontmost)일 때 "원격 세션 중"으로 인식할 원격 데스크탑 앱들의 번들 ID 접두사
    static let viewerBundlePrefixes = [
        "com.p5sys.jump",            // Jump Desktop
        "com.apple.ScreenSharing",   // macOS 화면 공유
        "com.edovia.screens",        // Screens 4/5
        "com.microsoft.rdc",         // Windows App (MS Remote Desktop)
        "com.realvnc.vncviewer",     // VNC Viewer
        "com.teamviewer.TeamViewer", // TeamViewer
        "com.philandro.anydesk",     // AnyDesk
        "com.carriez.rustdesk",      // RustDesk
        "tv.parsec.www",             // Parsec
        "com.splashtop",             // Splashtop
    ]

    private static let sessionTTL: TimeInterval = 600      // 원격 세션 신호 유효시간
    private static let sessionRefresh: TimeInterval = 240  // 세션 유지 재전송 주기
    private static let onlyRemoteDefaults = "OnlyDuringRemote"
    private static let pairingDuration: TimeInterval = 60

    let instanceID = UUID().uuidString
    let serviceName: String

    private let netQueue = DispatchQueue(label: "hangulsync.network")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]      // netQueue에서만 접근
    private var originByKey: [String: String] = [:]             // netQueue에서만 접근
    private var messageTimesByKey: [String: [Date]] = [:]       // netQueue에서만 접근
    private var trustedConnectionKeys: Set<String> = []         // netQueue에서만 접근
    private var pendingApprovalKeys: Set<String> = []            // netQueue에서만 접근
    private var lastBonjourResults: Set<NWBrowser.Result> = []  // netQueue에서만 접근
    private var retryTimer: Timer?
    private var pairingUntil = Date.distantPast

    // ↓ 메인 스레드에서만 접근
    private var suppressUntil = Date.distantPast
    private var lastKnownID: String?
    private var remoteActive: [String: Date] = [:]  // origin → 마지막 세션 신호 시각
    private var lastSessionBroadcast = Date.distantPast
    private var namesByOrigin: [String: String] = [:]
    private(set) var localViewerActive = false
    private(set) var readyPeerCount = 0
    /// 설정 창에 보여줄 피어 목록: (컴퓨터 이름, 연결 경로)
    private(set) var peerInfo: [(name: String, via: String)] = []

    let hostName = Host.current().localizedName ?? "Mac"

    var enabled = true { didSet { onStateChange?() } }

    /// true(기본): 원격 데스크탑 뷰어 사용 중일 때만 동기화
    var onlyDuringRemote: Bool {
        didSet {
            UserDefaults.standard.set(onlyDuringRemote, forKey: Self.onlyRemoteDefaults)
            onStateChange?()
        }
    }

    /// 지금 동기화가 실제로 동작하는 상태인가
    var syncAllowed: Bool {
        guard enabled else { return false }
        guard onlyDuringRemote else { return true }
        if localViewerActive { return true }
        let now = Date()
        return remoteActive.values.contains { now.timeIntervalSince($0) < Self.sessionTTL }
    }

    /// UI 갱신 콜백 (메인 스레드에서 호출됨)
    var onStateChange: (() -> Void)?

    init() {
        let host = Host.current().localizedName ?? "Mac"
        self.serviceName = "\(host)-\(instanceID.prefix(8))"
        if UserDefaults.standard.object(forKey: Self.onlyRemoteDefaults) == nil {
            self.onlyDuringRemote = true
        } else {
            self.onlyDuringRemote = UserDefaults.standard.bool(forKey: Self.onlyRemoteDefaults)
        }
    }

    func start() {
        lastKnownID = InputSourceManager.current()?.id
        observeLocalChanges()
        observeViewerApps()
        startListener()
        startBonjourBrowser()
        startTimer()
    }

    // MARK: - 로컬 입력 소스 변경 감지

    private func observeLocalChanges() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLocalChange()
        }
    }

    private func handleLocalChange() {
        onStateChange?()
        guard syncAllowed else { return }
        guard Date() >= suppressUntil else { return } // 원격 적용에 의한 에코 → 무시
        guard let cur = InputSourceManager.current(), cur.id != lastKnownID else { return }
        lastKnownID = cur.id
        send(input: cur)
    }

    // MARK: - 원격 데스크탑 뷰어 감지 (세션 게이트)
    // "뷰어 앱이 실행 중이면 원격 세션 중"으로 판정한다.
    // (frontmost 기준은 다른 앱만 잠깐 클릭해도 대기로 빠져 UX가 나쁘다)

    private func observeViewerApps() {
        let nc = NSWorkspace.shared.notificationCenter
        for event in [NSWorkspace.didLaunchApplicationNotification,
                      NSWorkspace.didTerminateApplicationNotification] {
            nc.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                self?.updateViewerState()
            }
        }
        updateViewerState()
    }

    private func updateViewerState() {
        let running = NSWorkspace.shared.runningApplications.contains { Self.isViewer($0) }
        setLocalViewer(active: running)
    }

    private static func isViewer(_ app: NSRunningApplication?) -> Bool {
        guard let id = app?.bundleIdentifier else { return false }
        return viewerBundlePrefixes.contains { id.hasPrefix($0) }
    }

    private func setLocalViewer(active: Bool) {
        guard active != localViewerActive else { return }
        localViewerActive = active
        lastSessionBroadcast = Date()
        send(session: active)
        if active, let cur = InputSourceManager.current() {
            // 세션 시작: 뷰어를 보고 있는 쪽(클라이언트)의 상태로 상대를 정렬
            lastKnownID = cur.id
            send(input: cur)
        }
        onStateChange?()
    }

    // MARK: - 메시지 송신

    private func send(input state: InputSourceManager.State) {
        push(SyncMessage(origin: instanceID, kind: .input,
                         sourceID: state.id, isKorean: state.isKorean))
    }

    private func send(session active: Bool) {
        push(SyncMessage(origin: instanceID, kind: .session, sessionActive: active))
    }

    private func push(_ msg: SyncMessage, requiresTrust: Bool = true) {
        guard var data = try? JSONEncoder().encode(msg) else { return }
        data.append(0x0A) // "\n"
        netQueue.async {
            for (key, conn) in self.connections {
                guard case .ready = conn.state else { continue }
                guard !requiresTrust || self.trustedConnectionKeys.contains(key) else { continue }
                conn.send(content: data, completion: .contentProcessed { _ in })
            }
        }
    }

    // MARK: - 메시지 수신 (netQueue에서 호출)

    private func handle(_ msg: SyncMessage, fromKey key: String) {
        guard msg.origin != instanceID else { return }
        if let boundOrigin = originByKey[key] {
            guard boundOrigin == msg.origin else {
                connections[key]?.cancel()
                return
            }
        } else {
            originByKey[key] = msg.origin
        }
        guard ProtocolSecurity.permits(
            msg.kind,
            enabled: enabled,
            trusted: trustedConnectionKeys.contains(key),
            pairingMode: Date() < pairingUntil
        ) else { return }

        switch msg.kind {
        case .hello:
            requestApproval(forKey: key, message: msg)
            DispatchQueue.main.async {
                self.namesByOrigin[msg.origin] = msg.name ?? "Mac"
            }
            recountPeers()
        case .session:
            let active = msg.sessionActive == true
            DispatchQueue.main.async {
                if active {
                    self.remoteActive[msg.origin] = Date()
                } else {
                    self.remoteActive.removeValue(forKey: msg.origin)
                }
                self.onStateChange?()
            }
        case .pair:
            // 1차 긴급 수정: 페어링 UI/상호 인증이 완성되기 전에는 키를
            // 저장하거나 응답하지 않는다. 명시적 60초 창도 후속 승인 흐름 전용이다.
            return
        case .input:
            guard let sourceID = msg.sourceID else { return }
            DispatchQueue.main.async {
                guard self.syncAllowed else { return }
                if let cur = InputSourceManager.current(), cur.id == sourceID { return } // 이미 동일
                self.suppressUntil = Date().addingTimeInterval(1.0)
                self.lastKnownID = sourceID
                InputSourceManager.apply(id: sourceID, isKorean: msg.isKorean ?? false)
                self.onStateChange?()
            }
        }
    }

    /// 후속 승인 UI에서만 호출한다. 이 창 자체는 어떤 키도 신뢰/저장하지 않는다.
    func beginPairingMode() {
        pairingUntil = Date().addingTimeInterval(Self.pairingDuration)
    }

    private func requestApproval(forKey key: String, message: SyncMessage) {
        guard !trustedConnectionKeys.contains(key),
              !pendingApprovalKeys.contains(key) else { return }
        pendingApprovalKeys.insert(key)
        let peerName = message.name ?? "Mac"
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L10n.t(.connectionRequest)
            alert.informativeText = String(format: L10n.t(.connectionRequestBody), peerName)
            alert.alertStyle = .warning
            alert.addButton(withTitle: L10n.t(.approve))
            alert.addButton(withTitle: L10n.t(.reject))
            let approved = alert.runModal() == .alertFirstButtonReturn
            self.netQueue.async {
                self.pendingApprovalKeys.remove(key)
                guard self.connections[key] != nil else { return }
                if approved {
                    self.trustedConnectionKeys.insert(key)
                    DispatchQueue.main.async {
                        guard self.enabled else { return }
                        if let cur = InputSourceManager.current() {
                            self.send(session: self.localViewerActive)
                            self.send(input: cur)
                        }
                    }
                } else {
                    self.connections[key]?.cancel()
                }
            }
        }
    }

    // MARK: - 네트워크 파라미터 (저지연 튜닝)

    /// TCP_NODELAY(Nagle 비활성)로 소형 메시지를 즉시 전송 — 체감 지연의 핵심 해결책
    private static func tunedTCPParams() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true            // 패킷 모아 보내기 비활성 → 즉시 전송
        tcp.enableKeepalive = true    // 끊긴 연결 조기 감지
        tcp.keepaliveIdle = 30
        tcp.connectionTimeout = 5
        let params = NWParameters(tls: nil, tcp: tcp)
        params.serviceClass = .responsiveData // 응답성 우선 QoS
        params.includePeerToPeer = true
        params.allowLocalEndpointReuse = true
        return params
    }

    // MARK: - 리스너 (수신 대기 + Bonjour 광고)

    private func startListener() {
        let params = Self.tunedTCPParams()
        do {
            let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
            l.service = NWListener.Service(name: serviceName, type: Self.serviceType)
            l.newConnectionHandler = { [weak self] conn in
                self?.adopt(conn, key: "in-\(UUID().uuidString)")
            }
            l.stateUpdateHandler = { state in
                NSLog("HangulSync listener: \(state)")
            }
            l.start(queue: netQueue)
            listener = l
        } catch {
            NSLog("HangulSync listener 시작 실패: \(error)")
        }
    }

    // MARK: - Bonjour 탐색 (같은 네트워크)

    private func startBonjourBrowser() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let b = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.lastBonjourResults = results
            self.connectBonjourPeers()
        }
        b.start(queue: netQueue)
        browser = b
    }

    /// netQueue에서 호출. 끊긴 피어가 있으면 다시 연결 시도.
    private func connectBonjourPeers() {
        for result in lastBonjourResults {
            guard case let NWEndpoint.service(name, _, _, _) = result.endpoint else { continue }
            guard name != serviceName else { continue } // 자기 자신 제외
            let key = "bonjour-\(name)"
            if connections[key] == nil {
                let conn = NWConnection(to: result.endpoint, using: Self.tunedTCPParams())
                adopt(conn, key: key)
            }
        }
    }

    // MARK: - 주기 작업 (20초): Tailscale 폴링·재연결·세션 유지·만료 정리

    private func startTimer() {
        let tick: () -> Void = { [weak self] in
            guard let self else { return }
            self.updateViewerState() // 뷰어 실행 상태 안전망 재확인
            self.pollTailscale()
            self.netQueue.async { self.connectBonjourPeers() }
            // 세션 신호 유지 재전송
            if self.localViewerActive,
               Date().timeIntervalSince(self.lastSessionBroadcast) > Self.sessionRefresh {
                self.lastSessionBroadcast = Date()
                self.send(session: true)
            }
            // 만료된 원격 세션 정리
            let now = Date()
            let before = self.remoteActive.count
            self.remoteActive = self.remoteActive.filter { now.timeIntervalSince($0.value) < Self.sessionTTL }
            if self.remoteActive.count != before { self.onStateChange?() }
        }
        tick()
        let t = Timer(timeInterval: 30, repeats: true) { _ in tick() }
        t.tolerance = 5 // OS가 타이머를 묶어 깨울 수 있게 여유 부여 (전력·CPU 절약)
        RunLoop.main.add(t, forMode: .common)
        retryTimer = t
    }

    // MARK: - Tailscale 탐색 (외부망)

    private func pollTailscale() {
        // 이미 Tailscale 경로로 연결돼 있으면 프로세스 실행 자체를 생략 (외부 프로세스 스폰 최소화)
        netQueue.async { [weak self] in
            guard let self else { return }
            let hasReadyTS = self.connections.contains { key, conn in
                guard key.hasPrefix("ts-") else { return false }
                if case .ready = conn.state { return true } else { return false }
            }
            if hasReadyTS { return }
            self.runTailscaleDiscovery()
        }
    }

    private func runTailscaleDiscovery() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self, let json = Self.runTailscaleStatus() else { return }
            guard let obj = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
                  let peers = obj["Peer"] as? [String: [String: Any]] else { return }
            for (_, peer) in peers {
                guard (peer["Online"] as? Bool) == true,
                      let ips = peer["TailscaleIPs"] as? [String],
                      let ip = ips.first(where: { !$0.contains(":") }) ?? ips.first else { continue }
                let key = "ts-\(ip)"
                self.netQueue.async {
                    guard self.connections[key] == nil else { return }
                    let conn = NWConnection(
                        host: NWEndpoint.Host(ip),
                        port: NWEndpoint.Port(rawValue: Self.port)!,
                        using: Self.tunedTCPParams()
                    )
                    self.adopt(conn, key: key)
                }
            }
        }
    }

    /// tailscale CLI 위치를 순서대로 탐색해 `status --json` 실행
    private static func runTailscaleStatus() -> Data? {
        let candidates = [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/opt/homebrew/bin/tailscale",
            "/usr/local/bin/tailscale",
        ]
        guard let bin = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return nil
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = ["status", "--json"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return proc.terminationStatus == 0 ? data : nil
    }

    // MARK: - 연결 관리

    /// 연결을 등록하고 시작 (netQueue에서 호출됨)
    private func adopt(_ conn: NWConnection, key: String) {
        connections[key] = conn
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.recountPeers()
                DispatchQueue.main.async {
                    // 이름 소개 (피어 목록·고유 카운트용)
                    self.push(
                        SyncMessage(origin: self.instanceID, kind: .hello, name: self.hostName),
                        requiresTrust: false
                    )
                    // 내가 원격 세션 중이면 새 피어에게 즉시 알림 + 상태 정렬
                    if self.localViewerActive {
                        self.send(session: true)
                        if let cur = InputSourceManager.current() { self.send(input: cur) }
                    }
                }
            case .failed(_), .cancelled:
                self.netQueue.async {
                    if self.connections[key] === conn {
                        self.connections.removeValue(forKey: key)
                        self.messageTimesByKey.removeValue(forKey: key)
                        self.trustedConnectionKeys.remove(key)
                        self.pendingApprovalKeys.remove(key)
                        if let origin = self.originByKey.removeValue(forKey: key),
                           !self.originByKey.values.contains(origin) {
                            DispatchQueue.main.async {
                                self.remoteActive.removeValue(forKey: origin)
                                self.onStateChange?()
                            }
                        }
                    }
                    self.recountPeers()
                }
            case .waiting(_):
                // 상대가 아직 앱을 안 켠 경우 등 — Network.framework가 자동 재시도하므로 유지
                self.recountPeers()
            default:
                break
            }
        }
        receiveLoop(conn, key: key, buffer: Data())
        conn.start(queue: netQueue)
    }

    /// 연결 개수가 아니라 "고유한 Mac" 기준으로 집계
    /// (두 맥이 서로 동시에 연결 + Tailscale 경로가 겹치면 연결은 2~4개가 되므로)
    private func recountPeers() {
        netQueue.async {
            var keyByOrigin: [String: String] = [:] // origin → 대표 연결 key
            for (key, conn) in self.connections {
                guard case .ready = conn.state else { continue }
                guard self.trustedConnectionKeys.contains(key) else { continue }
                guard let origin = self.originByKey[key] else { continue }
                // 경로 우선순위: 같은 네트워크 > Tailscale > 수신
                if let existing = keyByOrigin[origin] {
                    let rank: (String) -> Int = { $0.hasPrefix("bonjour") ? 0 : $0.hasPrefix("ts-") ? 1 : 2 }
                    if rank(key) < rank(existing) { keyByOrigin[origin] = key }
                } else {
                    keyByOrigin[origin] = key
                }
            }
            DispatchQueue.main.async {
                self.readyPeerCount = keyByOrigin.count
                self.peerInfo = keyByOrigin.map { origin, key in
                    let name = self.namesByOrigin[origin] ?? "Mac"
                    let via: L10n.Key = key.hasPrefix("bonjour") ? .viaLocalNetwork
                        : key.hasPrefix("ts-") ? .viaTailscale
                        : .viaIncoming
                    return (name, L10n.t(via))
                }.sorted { $0.name < $1.name }
                self.onStateChange?()
            }
        }
    }

    private func receiveLoop(_ conn: NWConnection, key: String, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            guard buf.count <= ProtocolSecurity.maxBufferBytes else {
                conn.cancel()
                return
            }
            while let newlineIndex = buf.firstIndex(of: 0x0A) {
                let line = buf.prefix(upTo: newlineIndex)
                buf = Data(buf.suffix(from: buf.index(after: newlineIndex)))
                guard line.count <= ProtocolSecurity.maxMessageBytes else {
                    conn.cancel()
                    return
                }
                if let msg = ProtocolSecurity.decode(Data(line)) {
                    let now = Date()
                    var recent = self.messageTimesByKey[key, default: []]
                        .filter { now.timeIntervalSince($0) < 1 }
                    guard recent.count < 30 else {
                        conn.cancel()
                        return
                    }
                    recent.append(now)
                    self.messageTimesByKey[key] = recent
                    self.handle(msg, fromKey: key)
                }
            }
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            self.receiveLoop(conn, key: key, buffer: buf)
        }
    }
}
