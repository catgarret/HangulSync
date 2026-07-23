import Foundation
import AppKit
import Carbon
import Network

/// 동기화 메시지 (newline-delimited JSON)
struct SyncMessage: Codable {
    var origin: String        // 보낸 인스턴스 UUID (자기 메시지 무시용)
    var kind: String?         // nil/"input" | "session" | "pair"
    var sourceID: String?     // input: 입력 소스 ID
    var isKorean: Bool?       // input: 한국어 여부 (폴백 매칭용)
    var sessionActive: Bool?  // session: 원격 세션 활성 여부
    var relayKey: String?     // pair: 릴레이 페어링 키 (직접 연결로만 전송)
}

/// 입력 소스 변경 감지 → 피어 전파, 피어 메시지 수신 → 로컬 적용.
/// 피어 경로: ① Bonjour(같은 네트워크/AWDL) ② Tailscale ③ 인터넷 릴레이(자동 페어링 후)
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
    private static let relayKeyDefaults = "RelayKey"
    private static let onlyRemoteDefaults = "OnlyDuringRemote"

    let instanceID = UUID().uuidString
    let serviceName: String

    private let netQueue = DispatchQueue(label: "hangulsync.network")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connections: [String: NWConnection] = [:]      // netQueue에서만 접근
    private var originByKey: [String: String] = [:]             // netQueue에서만 접근
    private var lastBonjourResults: Set<NWBrowser.Result> = []  // netQueue에서만 접근
    private var retryTimer: Timer?
    private let relay = RelayChannel()

    // ↓ 메인 스레드에서만 접근
    private var suppressUntil = Date.distantPast
    private var lastKnownID: String?
    private var remoteActive: [String: Date] = [:]  // origin → 마지막 세션 신호 시각
    private var lastSessionBroadcast = Date.distantPast
    private(set) var localViewerActive = false
    private(set) var readyPeerCount = 0

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
        relay.onMessage = { [weak self] msg in
            self?.netQueue.async { self?.handle(msg, fromKey: "relay") }
        }
        if let key = UserDefaults.standard.string(forKey: Self.relayKeyDefaults) {
            relay.configure(key: key)
        }
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

    private func observeViewerApps() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.setLocalViewer(active: Self.isViewer(app))
        }
        setLocalViewer(active: Self.isViewer(NSWorkspace.shared.frontmostApplication))
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
        push(SyncMessage(origin: instanceID, kind: "input",
                         sourceID: state.id, isKorean: state.isKorean))
    }

    private func send(session active: Bool) {
        push(SyncMessage(origin: instanceID, kind: "session", sessionActive: active))
    }

    private func send(pairKey: String) {
        push(SyncMessage(origin: instanceID, kind: "pair", relayKey: pairKey), viaRelay: false)
    }

    private func push(_ msg: SyncMessage, viaRelay: Bool = true) {
        guard var data = try? JSONEncoder().encode(msg) else { return }
        data.append(0x0A) // "\n"
        netQueue.async {
            for conn in self.connections.values {
                guard case .ready = conn.state else { continue }
                conn.send(content: data, completion: .contentProcessed { _ in })
            }
        }
        if viaRelay {
            DispatchQueue.main.async {
                // 직접 연결된 피어가 없을 때만 릴레이 사용
                if self.readyPeerCount == 0 { self.relay.publish(msg) }
            }
        }
    }

    // MARK: - 메시지 수신 (netQueue에서 호출)

    private func handle(_ msg: SyncMessage, fromKey key: String) {
        guard msg.origin != instanceID else { return }
        if key != "relay" { originByKey[key] = msg.origin }

        switch msg.kind {
        case "session":
            let active = msg.sessionActive == true
            DispatchQueue.main.async {
                if active {
                    self.remoteActive[msg.origin] = Date()
                } else {
                    self.remoteActive.removeValue(forKey: msg.origin)
                }
                self.onStateChange?()
            }
        case "pair":
            guard let theirs = msg.relayKey else { return }
            DispatchQueue.main.async { self.mergePairKey(theirs) }
        default: // input
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

    // MARK: - 릴레이 페어링 (직접 연결됐을 때 키 자동 합의·저장)

    private var relayKey: String? {
        UserDefaults.standard.string(forKey: Self.relayKeyDefaults)
    }

    private func ensureRelayKeyAndShare() {
        let key: String
        if let existing = relayKey {
            key = existing
        } else {
            key = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            UserDefaults.standard.set(key, forKey: Self.relayKeyDefaults)
        }
        relay.configure(key: key)
        send(pairKey: key)
    }

    private func mergePairKey(_ theirs: String) {
        let merged = relayKey.map { min($0, theirs) } ?? theirs
        guard merged != relayKey else { return }
        UserDefaults.standard.set(merged, forKey: Self.relayKeyDefaults)
        relay.configure(key: merged)
        send(pairKey: merged) // 상대도 같은 키로 수렴하도록 재전송
    }

    // MARK: - 리스너 (수신 대기 + Bonjour 광고)

    private func startListener() {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = true
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
                let conn = NWConnection(to: result.endpoint, using: .tcp)
                adopt(conn, key: key)
            }
        }
    }

    // MARK: - 주기 작업 (20초): Tailscale 폴링·재연결·세션 유지·만료 정리

    private func startTimer() {
        let tick: () -> Void = { [weak self] in
            guard let self else { return }
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
        let t = Timer(timeInterval: 20, repeats: true) { _ in tick() }
        RunLoop.main.add(t, forMode: .common)
        retryTimer = t
    }

    // MARK: - Tailscale 탐색 (외부망)

    private func pollTailscale() {
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
                        using: .tcp
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
                    // 릴레이 키 합의·공유 (직접 연결이 생겼을 때)
                    self.ensureRelayKeyAndShare()
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

    private func recountPeers() {
        netQueue.async {
            let count = self.connections.values.filter {
                if case .ready = $0.state { return true } else { return false }
            }.count
            DispatchQueue.main.async {
                self.readyPeerCount = count
                self.onStateChange?()
            }
        }
    }

    private func receiveLoop(_ conn: NWConnection, key: String, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            while let newlineIndex = buf.firstIndex(of: 0x0A) {
                let line = buf.prefix(upTo: newlineIndex)
                buf = Data(buf.suffix(from: buf.index(after: newlineIndex)))
                if let msg = try? JSONDecoder().decode(SyncMessage.self, from: line) {
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
