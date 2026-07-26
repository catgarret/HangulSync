import CryptoKit
import Foundation
import Security

struct SecureIdentity {
    private static let service = "com.local.hangulsync.identity"
    private static let account = "curve25519-key-agreement-v1"

    let privateKey: Curve25519.KeyAgreement.PrivateKey

    var publicKeyData: Data { privateKey.publicKey.rawRepresentation }
    var publicKeyBase64: String { publicKeyData.base64EncodedString() }
    var deviceID: String {
        SHA256.hash(data: publicKeyData).map { String(format: "%02x", $0) }.joined()
    }

    static func loadOrCreate() -> SecureIdentity? {
        if let data = readKey(),
           let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data) {
            return SecureIdentity(privateKey: key)
        }
        let key = Curve25519.KeyAgreement.PrivateKey()
        guard saveKey(key.rawRepresentation) else { return nil }
        return SecureIdentity(privateKey: key)
    }

    func sharedSecret(with publicKeyBase64: String) -> SharedSecret? {
        guard let data = Data(base64Encoded: publicKeyBase64),
              data.count == 32,
              let publicKey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: data)
        else { return nil }
        return try? privateKey.sharedSecretFromKeyAgreement(with: publicKey)
    }

    func confirmationCode(with publicKeyBase64: String) -> String? {
        guard let secret = sharedSecret(with: publicKeyBase64) else { return nil }
        let key = secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data("HangulSync pairing v1".utf8),
            sharedInfo: Data(),
            outputByteCount: 4
        )
        let value = key.withUnsafeBytes { raw -> UInt32 in
            raw.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }
        return String(format: "%06u", value % 1_000_000)
    }

    static func deviceID(for publicKeyBase64: String) -> String? {
        guard let data = Data(base64Encoded: publicKeyBase64), data.count == 32 else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func readKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private static func saveKey(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updated = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updated == errSecSuccess { return true }
        guard updated == errSecItemNotFound else { return false }
        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }
}
