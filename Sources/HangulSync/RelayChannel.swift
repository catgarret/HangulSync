import CryptoKit
import Foundation

private struct RelayPlaintext: Codable {
    let sender: String
    let recipient: String
    let sessionID: String
    let sequence: UInt64
    let timestamp: TimeInterval
    let message: SyncMessage
}

private struct RelayCiphertext: Codable {
    let ciphertext: String
}

struct RelayKeyMaterial {
    let topic: String
    let contentKey: SymmetricKey

    init(sharedSecret: SharedSecret, localID: String, peerID: String) {
        let ids = [localID, peerID].sorted().joined(separator: ":")
        let salt = Data("HangulSync relay v1".utf8)
        let topicKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("topic:\(ids)".utf8),
            outputByteCount: 32
        )
        contentKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("content:\(ids)".utf8),
            outputByteCount: 32
        )
        topic = topicKey.withUnsafeBytes {
            $0.map { String(format: "%02x", $0) }.joined()
        }
    }
}

/// Pairwise end-to-end encrypted ntfy transport.
final class RelayChannel: NSObject, URLSessionDataDelegate {
    var onMessage: ((SyncMessage, String) -> Void)?

    private struct Peer {
        let id: String
        let topic: String
        let key: SymmetricKey
        var sequence: UInt64 = 0
        var task: URLSessionDataTask?
        var buffer = Data()
        var receivedSequences: [String: UInt64] = [:]
    }

    private let localID: String
    private let sessionID = UUID().uuidString
    private let lock = NSLock()
    private var peers: [String: Peer] = [:]
    private var peerByTaskID: [Int: String] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 24 * 3600
        config.timeoutIntervalForResource = 7 * 24 * 3600
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()

    init(localID: String) {
        self.localID = localID
    }

    func configure(peerID: String, sharedSecret: SharedSecret) {
        let material = RelayKeyMaterial(
            sharedSecret: sharedSecret,
            localID: localID,
            peerID: peerID
        )
        lock.lock()
        let exists = peers[peerID] != nil
        if !exists {
            peers[peerID] = Peer(id: peerID, topic: material.topic, key: material.contentKey)
        }
        lock.unlock()
        if !exists { subscribe(peerID: peerID) }
    }

    func publish(_ message: SyncMessage) {
        lock.lock()
        let ids = Array(peers.keys)
        lock.unlock()
        for peerID in ids { publish(message, to: peerID) }
    }

    func remove(peerID: String) {
        lock.lock()
        let task = peers.removeValue(forKey: peerID)?.task
        if let task { peerByTaskID.removeValue(forKey: task.taskIdentifier) }
        lock.unlock()
        task?.cancel()
    }

    private func publish(_ message: SyncMessage, to peerID: String) {
        lock.lock()
        guard var peer = peers[peerID] else { lock.unlock(); return }
        peer.sequence &+= 1
        peers[peerID] = peer
        lock.unlock()

        let plain = RelayPlaintext(
            sender: localID,
            recipient: peerID,
            sessionID: sessionID,
            sequence: peer.sequence,
            timestamp: Date().timeIntervalSince1970,
            message: message
        )
        guard let data = try? JSONEncoder().encode(plain),
              let sealed = try? ChaChaPoly.seal(data, using: peer.key),
              let url = URL(string: "https://ntfy.sh/hangulsync-\(peer.topic)")
        else { return }
        let body = RelayCiphertext(ciphertext: sealed.combined.base64EncodedString())
        guard let encoded = try? JSONEncoder().encode(body) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = encoded
        request.setValue("no", forHTTPHeaderField: "X-Cache")
        request.setValue("no", forHTTPHeaderField: "X-Firebase")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        session.dataTask(with: request).resume()
    }

    private func subscribe(peerID: String) {
        lock.lock()
        guard let peer = peers[peerID],
              let url = URL(string: "https://ntfy.sh/hangulsync-\(peer.topic)/json")
        else { lock.unlock(); return }
        lock.unlock()
        var request = URLRequest(url: url)
        request.setValue("no", forHTTPHeaderField: "X-Cache")
        request.setValue("no", forHTTPHeaderField: "X-Firebase")
        let task = session.dataTask(with: request)
        lock.lock()
        peers[peerID]?.task = task
        peerByTaskID[task.taskIdentifier] = peerID
        lock.unlock()
        task.resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard let peerID = peerByTaskID[dataTask.taskIdentifier], var peer = peers[peerID]
        else { lock.unlock(); return }
        peer.buffer.append(data)
        guard peer.buffer.count <= ProtocolSecurity.maxBufferBytes else {
            peers[peerID]?.buffer = Data()
            lock.unlock()
            dataTask.cancel()
            return
        }
        var messages: [SyncMessage] = []
        while let newline = peer.buffer.firstIndex(of: 0x0A) {
            let line = Data(peer.buffer.prefix(upTo: newline))
            peer.buffer = Data(peer.buffer.suffix(from: peer.buffer.index(after: newline)))
            guard line.count <= ProtocolSecurity.maxMessageBytes * 2,
                  let event = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  event["event"] as? String == "message",
                  let text = event["message"] as? String,
                  let cipherData = text.data(using: .utf8),
                  let wrapper = try? JSONDecoder().decode(RelayCiphertext.self, from: cipherData),
                  let combined = Data(base64Encoded: wrapper.ciphertext),
                  let box = try? ChaChaPoly.SealedBox(combined: combined),
                  let opened = try? ChaChaPoly.open(box, using: peer.key),
                  let plain = try? JSONDecoder().decode(RelayPlaintext.self, from: opened),
                  plain.sender == peerID, plain.recipient == localID,
                  plain.message.origin == peerID,
                  abs(Date().timeIntervalSince1970 - plain.timestamp) <= 120,
                  ProtocolSecurity.validate(plain.message)
            else { continue }
            let last = peer.receivedSequences[plain.sessionID] ?? 0
            guard plain.sequence > last else { continue }
            guard peer.receivedSequences[plain.sessionID] != nil
                    || peer.receivedSequences.count < 16 else { continue }
            peer.receivedSequences[plain.sessionID] = plain.sequence
            messages.append(plain.message)
        }
        peers[peerID] = peer
        lock.unlock()
        for message in messages { onMessage?(message, peerID) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        guard let peerID = peerByTaskID.removeValue(forKey: task.taskIdentifier) else {
            lock.unlock()
            return
        }
        peers[peerID]?.task = nil
        lock.unlock()
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.subscribe(peerID: peerID)
        }
    }
}
