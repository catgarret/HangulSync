import CryptoKit
import Foundation

struct PairingInvite: Codable {
    let version: Int
    let secret: String
    let publicKey: String
    let name: String

    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ value: String) -> PairingInvite? {
        var base64 = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
              data.count <= 4096,
              let invite = try? JSONDecoder().decode(PairingInvite.self, from: data),
              invite.version == 1,
              Data(base64Encoded: invite.secret)?.count == 32,
              SecureIdentity.deviceID(for: invite.publicKey) != nil,
              !invite.name.isEmpty, invite.name.count <= 128
        else { return nil }
        return invite
    }
}

struct PairingRendezvousKeyMaterial {
    let topic: String
    let contentKey: SymmetricKey

    init(secret: Data) {
        let input = SymmetricKey(data: secret)
        let salt = Data("HangulSync remote pairing v1".utf8)
        let topicKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: input, salt: salt,
            info: Data("topic".utf8), outputByteCount: 24
        )
        contentKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: input, salt: salt,
            info: Data("content".utf8), outputByteCount: 32
        )
        topic = topicKey.withUnsafeBytes {
            $0.map { String(format: "%02x", $0) }.joined()
        }
    }
}

private struct RendezvousPeer: Codable {
    let publicKey: String
    let name: String
    let timestamp: TimeInterval
    let nonce: String
    let approved: Bool
}

private struct RendezvousCiphertext: Codable {
    let ciphertext: String
}

/// 120초 동안만 존재하는 ntfy 기반 원격 페어링 채널.
/// 토픽과 본문은 초대장 속 256-bit 비밀값에서 HKDF로 각각 분리한다.
final class PairingRendezvous: NSObject, URLSessionDataDelegate {
    var onPeer: ((String, String, Bool) -> Void)?
    var onError: ((Int) -> Void)?

    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var key: SymmetricKey?
    private var topic: String?
    private var acceptedNonces: Set<String> = []
    private var generation = UUID()
    private var errorReported = false

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 125
        config.timeoutIntervalForResource = 125
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }()

    func createInvite(publicKey: String, name: String) -> String? {
        let secret = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) })
        let invite = PairingInvite(
            version: 1,
            secret: secret.base64EncodedString(),
            publicKey: publicKey,
            name: name
        )
        guard let encoded = invite.encoded() else { return nil }
        begin(material: PairingRendezvousKeyMaterial(secret: secret))
        return encoded
    }

    func join(inviteText: String, publicKey: String, name: String) -> Bool {
        guard let invite = PairingInvite.decode(inviteText),
              let secret = Data(base64Encoded: invite.secret)
        else { return false }
        let material = PairingRendezvousKeyMaterial(secret: secret)
        begin(material: material)
        onPeer?(invite.publicKey, invite.name, false)

        let peer = RendezvousPeer(
            publicKey: publicKey,
            name: name,
            timestamp: Date().timeIntervalSince1970,
            nonce: UUID().uuidString,
            approved: false
        )
        for delay in [0.4, 2.0, 6.0] {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.publish(peer, material: material)
            }
        }
        return true
    }

    func publishApproval(publicKey: String, name: String) {
        lock.lock()
        guard let key, let topic else { lock.unlock(); return }
        lock.unlock()
        let peer = RendezvousPeer(
            publicKey: publicKey,
            name: name,
            timestamp: Date().timeIntervalSince1970,
            nonce: UUID().uuidString,
            approved: true
        )
        for delay in [0.0, 1.5, 5.0] {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.publish(peer, topic: topic, key: key)
            }
        }
    }

    func cancel() {
        lock.lock()
        generation = UUID()
        let oldTask = task
        task = nil
        key = nil
        topic = nil
        buffer.removeAll()
        acceptedNonces.removeAll()
        errorReported = false
        lock.unlock()
        oldTask?.cancel()
    }

    private func begin(material: PairingRendezvousKeyMaterial) {
        cancel()
        guard let url = URL(string: "https://ntfy.sh/hangulsync-pair-\(material.topic)/json")
        else { return }
        var request = URLRequest(url: url)
        request.setValue("no", forHTTPHeaderField: "X-Cache")
        request.setValue("no", forHTTPHeaderField: "X-Firebase")
        let newTask = session.dataTask(with: request)
        lock.lock()
        key = material.contentKey
        topic = material.topic
        task = newTask
        let currentGeneration = generation
        lock.unlock()
        newTask.resume()
        DispatchQueue.global().asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.lock.lock()
            let current = self?.generation == currentGeneration
            self?.lock.unlock()
            if current { self?.cancel() }
        }
    }

    private func publish(_ peer: RendezvousPeer, material: PairingRendezvousKeyMaterial) {
        publish(peer, topic: material.topic, key: material.contentKey)
    }

    private func publish(_ peer: RendezvousPeer, topic: String, key: SymmetricKey) {
        guard let plain = try? JSONEncoder().encode(peer),
              let sealed = try? ChaChaPoly.seal(plain, using: key),
              let body = try? JSONEncoder().encode(
                RendezvousCiphertext(ciphertext: sealed.combined.base64EncodedString())
              ),
              let url = URL(string: "https://ntfy.sh/hangulsync-pair-\(topic)")
        else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("no", forHTTPHeaderField: "X-Cache")
        request.setValue("no", forHTTPHeaderField: "X-Firebase")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        session.dataTask(with: request) { [weak self] _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? (error == nil ? 0 : -1)
            guard !(200..<300).contains(status) else { return }
            self?.reportError(status: status)
        }.resume()
    }

    private func reportError(status: Int) {
        lock.lock()
        guard !errorReported else { lock.unlock(); return }
        errorReported = true
        lock.unlock()
        onError?(status)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard dataTask === task, let key else { lock.unlock(); return }
        buffer.append(data)
        guard buffer.count <= ProtocolSecurity.maxBufferBytes else {
            lock.unlock()
            cancel()
            return
        }
        var peers: [RendezvousPeer] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = Data(buffer.prefix(upTo: newline))
            buffer = Data(buffer.suffix(from: buffer.index(after: newline)))
            guard let event = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  event["event"] as? String == "message",
                  let text = event["message"] as? String,
                  let wrapperData = text.data(using: .utf8),
                  let wrapper = try? JSONDecoder().decode(RendezvousCiphertext.self, from: wrapperData),
                  let combined = Data(base64Encoded: wrapper.ciphertext),
                  let box = try? ChaChaPoly.SealedBox(combined: combined),
                  let opened = try? ChaChaPoly.open(box, using: key),
                  let peer = try? JSONDecoder().decode(RendezvousPeer.self, from: opened),
                  abs(Date().timeIntervalSince1970 - peer.timestamp) <= 120,
                  SecureIdentity.deviceID(for: peer.publicKey) != nil,
                  !acceptedNonces.contains(peer.nonce)
            else { continue }
            acceptedNonces.insert(peer.nonce)
            peers.append(peer)
        }
        lock.unlock()
        for peer in peers { onPeer?(peer.publicKey, peer.name, peer.approved) }
    }
}
