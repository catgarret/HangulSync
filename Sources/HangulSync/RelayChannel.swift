import Foundation

/// 인터넷 릴레이 (ntfy.sh) — LAN도 Tailscale도 없는 환경을 위한 폴백 경로.
/// 두 Mac이 직접 연결됐을 때 자동 교환·저장된 비밀 키로 전용 토픽을 구성한다.
/// 주고받는 내용은 입력 소스 ID뿐이며, 토픽 이름은 무작위 128bit 키라 추측이 불가능하다.
final class RelayChannel: NSObject, URLSessionDataDelegate {

    var onMessage: ((SyncMessage) -> Void)?

    private var key: String?
    private var subscribeTask: URLSessionDataTask?
    private var buffer = Data()

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 24 * 3600
        cfg.timeoutIntervalForResource = 7 * 24 * 3600
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }()

    private func topicURL(suffix: String = "") -> URL? {
        guard let key else { return nil }
        return URL(string: "https://ntfy.sh/hangulsync-\(key)\(suffix)")
    }

    /// 페어링 키 설정 (변경 시 재구독)
    func configure(key newKey: String) {
        guard newKey != key else { return }
        key = newKey
        resubscribe()
    }

    func publish(_ msg: SyncMessage) {
        guard let url = topicURL(), let data = try? JSONEncoder().encode(msg) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = data
        session.dataTask(with: req).resume()
    }

    private func resubscribe() {
        subscribeTask?.cancel()
        buffer = Data()
        guard let url = topicURL(suffix: "/json") else { return }
        let task = session.dataTask(with: URLRequest(url: url))
        subscribeTask = task
        task.resume()
    }

    // MARK: - URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard dataTask === subscribeTask else { return }
        buffer.append(data)
        while let idx = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer.prefix(upTo: idx))
            buffer = Data(buffer.suffix(from: buffer.index(after: idx)))
            guard let event = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  event["event"] as? String == "message",
                  let payload = (event["message"] as? String)?.data(using: .utf8),
                  let msg = try? JSONDecoder().decode(SyncMessage.self, from: payload) else { continue }
            onMessage?(msg)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard task === subscribeTask else { return }
        // 스트림 끊김 → 5초 후 재구독
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.resubscribe()
        }
    }
}
