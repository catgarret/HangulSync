import Foundation

enum SyncMessageKind: String, Codable {
    case input
    case session
    case pair
    case hello
}

/// Newline-delimited JSON message used on direct connections.
struct SyncMessage: Codable {
    var origin: String
    var kind: SyncMessageKind
    var sourceID: String? = nil
    var isKorean: Bool? = nil
    var sessionActive: Bool? = nil
    var relayKey: String? = nil
    var name: String? = nil
    var publicKey: String? = nil
    var pairingRequest: Bool? = nil
}

enum ProtocolSecurity {
    static let maxMessageBytes = 4 * 1024
    static let maxBufferBytes = 8 * 1024
    static let maxOriginLength = 64
    static let maxNameLength = 100
    static let maxSourceIDLength = 256
    static let relayKeyLength = 32

    static func isValidRelayKey(_ key: String) -> Bool {
        guard key.utf8.count == relayKeyLength else { return false }
        return key.utf8.allSatisfy {
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }
    }

    static func validate(_ message: SyncMessage) -> Bool {
        guard !message.origin.isEmpty,
              message.origin.utf8.count <= maxOriginLength else { return false }

        if let name = message.name, name.utf8.count > maxNameLength { return false }
        if let sourceID = message.sourceID,
           sourceID.isEmpty || sourceID.utf8.count > maxSourceIDLength { return false }
        if let relayKey = message.relayKey, !isValidRelayKey(relayKey) { return false }
        if let publicKey = message.publicKey,
           publicKey.utf8.count > 64 || Data(base64Encoded: publicKey)?.count != 32 {
            return false
        }

        switch message.kind {
        case .hello:
            return message.name != nil && message.publicKey != nil
                && message.sourceID == nil && message.isKorean == nil
                && message.sessionActive == nil && message.relayKey == nil
        case .input:
            return message.sourceID != nil
                && message.sessionActive == nil && message.relayKey == nil
                && message.name == nil && message.publicKey == nil
                && message.pairingRequest == nil
        case .session:
            return message.sessionActive != nil
                && message.sourceID == nil && message.isKorean == nil
                && message.relayKey == nil && message.name == nil
                && message.publicKey == nil && message.pairingRequest == nil
        case .pair:
            return message.relayKey != nil
                && message.sourceID == nil && message.isKorean == nil
                && message.sessionActive == nil && message.name == nil
                && message.publicKey == nil && message.pairingRequest == nil
        }
    }

    static func decode(_ data: Data) -> SyncMessage? {
        guard !data.isEmpty, data.count <= maxMessageBytes,
              let message = try? JSONDecoder().decode(SyncMessage.self, from: data),
              validate(message) else { return nil }
        return message
    }

    static func permits(
        _ kind: SyncMessageKind,
        enabled: Bool,
        trusted: Bool,
        pairingMode: Bool
    ) -> Bool {
        if kind == .hello { return true }
        guard enabled, trusted else { return false }
        if kind == .pair { return pairingMode }
        return true
    }
}

enum SemanticVersion: Comparable, Equatable {
    case version(Int, Int, Int)

    init?(_ value: String) {
        let text = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2])
        else { return nil }
        self = .version(major, minor, patch)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        switch (lhs, rhs) {
        case let (.version(lMajor, lMinor, lPatch), .version(rMajor, rMinor, rPatch)):
            return (lMajor, lMinor, lPatch) < (rMajor, rMinor, rPatch)
        }
    }
}
