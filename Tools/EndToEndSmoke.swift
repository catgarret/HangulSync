import CryptoKit
import Foundation

// 실제 ntfy를 사용해 초대 교환부터 암호화 릴레이까지 검증:
// swiftc Tools/EndToEndSmoke.swift Sources/HangulSync/{PairingRendezvous,RelayChannel,SecureIdentity,ProtocolSecurity}.swift -o /tmp/hangulsync-e2e && /tmp/hangulsync-e2e
@main
enum EndToEndSmoke {
    static func main() {
        let firstIdentity = SecureIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
        let secondIdentity = SecureIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
        let firstPairing = PairingRendezvous()
        let secondPairing = PairingRendezvous()
        let pairingDone = DispatchSemaphore(value: 0)
        var receivedSecondKey: String?

        firstPairing.onPeer = { key, _ in
            guard key == secondIdentity.publicKeyBase64 else { return }
            receivedSecondKey = key
            pairingDone.signal()
        }
        secondPairing.onPeer = { key, _ in
            guard key == firstIdentity.publicKeyBase64 else { return }
        }

        guard let invite = firstPairing.createInvite(
            publicKey: firstIdentity.publicKeyBase64,
            name: "First Mac"
        ), secondPairing.join(
            inviteText: invite,
            publicKey: secondIdentity.publicKeyBase64,
            name: "Second Mac"
        ) else {
            fatalError("PAIRING_SETUP_FAILED")
        }
        guard pairingDone.wait(timeout: .now() + 15) == .success,
              receivedSecondKey == secondIdentity.publicKeyBase64
        else {
            fatalError("PAIRING_ROUND_TRIP_FAILED")
        }
        firstPairing.cancel()
        secondPairing.cancel()

        guard let firstSecret = firstIdentity.sharedSecret(with: secondIdentity.publicKeyBase64),
              let secondSecret = secondIdentity.sharedSecret(with: firstIdentity.publicKeyBase64)
        else {
            fatalError("KEY_AGREEMENT_FAILED")
        }
        let firstRelay = RelayChannel(localID: firstIdentity.deviceID)
        let secondRelay = RelayChannel(localID: secondIdentity.deviceID)
        let relayDone = DispatchSemaphore(value: 0)
        secondRelay.onMessage = { message, peerID in
            guard peerID == firstIdentity.deviceID,
                  message.origin == firstIdentity.deviceID,
                  message.sourceID == "com.apple.keylayout.ABC"
            else { return }
            relayDone.signal()
        }
        firstRelay.configure(peerID: secondIdentity.deviceID, sharedSecret: firstSecret)
        secondRelay.configure(peerID: firstIdentity.deviceID, sharedSecret: secondSecret)

        Thread.sleep(forTimeInterval: 1.5)
        firstRelay.publish(
            SyncMessage(
                origin: firstIdentity.deviceID,
                kind: .input,
                sourceID: "com.apple.keylayout.ABC",
                isKorean: false
            )
        )
        guard relayDone.wait(timeout: .now() + 15) == .success else {
            fatalError("ENCRYPTED_RELAY_FAILED")
        }
        print("END_TO_END_PASS")
    }
}
