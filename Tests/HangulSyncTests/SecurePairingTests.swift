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
        let firstContent = firstMaterial.contentKey.withUnsafeBytes { Data($0) }
        let secondContent = secondMaterial.contentKey.withUnsafeBytes { Data($0) }
        XCTAssertEqual(firstContent, secondContent)
        XCTAssertNotEqual(Data(hex: firstMaterial.topic), firstContent)
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
