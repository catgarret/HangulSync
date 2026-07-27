import CryptoKit
import XCTest
@testable import HangulSync

final class SecurePairingTests: XCTestCase {
    func testBothDevicesDeriveSameConfirmationCode() throws {
        let first = SecureIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
        let second = SecureIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())

        XCTAssertEqual(
            first.confirmationCode(with: second.publicKeyBase64),
            second.confirmationCode(with: first.publicKeyBase64)
        )
        XCTAssertNotEqual(first.deviceID, second.deviceID)
        XCTAssertEqual(
            SecureIdentity.deviceID(for: first.publicKeyBase64),
            first.deviceID
        )
    }

    func testRelayDerivationIsSymmetricAndSeparatesTopicFromContentKey() throws {
        let first = SecureIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
        let second = SecureIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
        let firstSecret = try XCTUnwrap(first.sharedSecret(with: second.publicKeyBase64))
        let secondSecret = try XCTUnwrap(second.sharedSecret(with: first.publicKeyBase64))
        let firstMaterial = RelayKeyMaterial(
            sharedSecret: firstSecret,
            localID: first.deviceID,
            peerID: second.deviceID
        )
        let secondMaterial = RelayKeyMaterial(
            sharedSecret: secondSecret,
            localID: second.deviceID,
            peerID: first.deviceID
        )

        XCTAssertEqual(firstMaterial.topic, secondMaterial.topic)
        XCTAssertLessThanOrEqual("hangulsync-\(firstMaterial.topic)".count, 64)
        let firstContent = firstMaterial.contentKey.withUnsafeBytes { Data($0) }
        let secondContent = secondMaterial.contentKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(firstContent, secondContent)
        XCTAssertNotEqual(Data(hex: firstMaterial.topic), firstContent)
    }

    func testRemotePairingInviteRoundTripsAndRejectsTampering() throws {
        let identity = SecureIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
        let secret = Data(repeating: 0x42, count: 32)
        let invite = PairingInvite(
            version: 1,
            secret: secret.base64EncodedString(),
            publicKey: identity.publicKeyBase64,
            name: "Test Mac"
        )
        let encoded = try XCTUnwrap(invite.encoded())
        let decoded = try XCTUnwrap(PairingInvite.decode(encoded))

        XCTAssertEqual(decoded.publicKey, identity.publicKeyBase64)
        XCTAssertEqual(decoded.name, "Test Mac")
        XCTAssertNil(PairingInvite.decode(encoded + "broken"))
    }

    func testRemotePairingSeparatesTopicAndContentKeys() {
        let material = PairingRendezvousKeyMaterial(secret: Data(repeating: 0x23, count: 32))
        let content = material.contentKey.withUnsafeBytes { Data($0) }

        XCTAssertEqual(material.topic.count, 48)
        XCTAssertLessThanOrEqual("hangulsync-pair-\(material.topic)".count, 64)
        XCTAssertNotEqual(Data(hex: material.topic), content)
    }

    func testTrustedRelayPeerIsIncludedInConnectedCount() {
        let inventory = PeerInventory.includingRelayFallbacks(
            direct: [:],
            trustedOrigins: ["trusted-device"]
        )

        XCTAssertEqual(inventory.count, 1)
        XCTAssertEqual(inventory["trusted-device"], "relay-trusted-device")
    }

    func testDirectConnectionTakesPriorityOverRelayFallback() {
        let inventory = PeerInventory.includingRelayFallbacks(
            direct: ["trusted-device": "ts-100.64.0.1"],
            trustedOrigins: ["trusted-device"]
        )

        XCTAssertEqual(inventory["trusted-device"], "ts-100.64.0.1")
    }
}

private extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
