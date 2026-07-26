import XCTest
@testable import HangulSync

final class ProtocolSecurityTests: XCTestCase {
    func testValidMessages() {
        XCTAssertTrue(ProtocolSecurity.validate(
            SyncMessage(origin: "peer", kind: .hello, name: "Mac")
        ))
        XCTAssertTrue(ProtocolSecurity.validate(
            SyncMessage(origin: "peer", kind: .input, sourceID: "com.apple.keylayout.US", isKorean: false)
        ))
    }

    func testUnknownAndMalformedKindsAreRejected() {
        let unknown = Data(#"{"origin":"peer","kind":"surprise","sourceID":"x"}"#.utf8)
        XCTAssertNil(ProtocolSecurity.decode(unknown))
        XCTAssertNil(ProtocolSecurity.decode(Data("{".utf8)))
    }

    func testRelayKeyMustBeExactly32HexCharacters() {
        XCTAssertTrue(ProtocolSecurity.isValidRelayKey(String(repeating: "a", count: 32)))
        XCTAssertFalse(ProtocolSecurity.isValidRelayKey(""))
        XCTAssertFalse(ProtocolSecurity.isValidRelayKey(String(repeating: "a", count: 31)))
        XCTAssertFalse(ProtocolSecurity.isValidRelayKey(String(repeating: "a", count: 33)))
        XCTAssertFalse(ProtocolSecurity.isValidRelayKey(String(repeating: "z", count: 32)))
    }

    func testFieldAndMessageLimits() throws {
        XCTAssertFalse(ProtocolSecurity.validate(
            SyncMessage(origin: String(repeating: "a", count: 65), kind: .hello, name: "Mac")
        ))
        XCTAssertFalse(ProtocolSecurity.validate(
            SyncMessage(origin: "peer", kind: .hello, name: String(repeating: "a", count: 101))
        ))
        XCTAssertFalse(ProtocolSecurity.validate(
            SyncMessage(origin: "peer", kind: .input, sourceID: String(repeating: "a", count: 257))
        ))
        XCTAssertNil(ProtocolSecurity.decode(Data(repeating: 0x20, count: ProtocolSecurity.maxMessageBytes + 1)))
    }

    func testMessageShapeMustMatchKind() {
        XCTAssertFalse(ProtocolSecurity.validate(
            SyncMessage(origin: "peer", kind: .input, sourceID: nil)
        ))
        XCTAssertFalse(ProtocolSecurity.validate(
            SyncMessage(origin: "peer", kind: .session, sourceID: "spoof", sessionActive: true)
        ))
        XCTAssertFalse(ProtocolSecurity.validate(
            SyncMessage(origin: "peer", kind: .pair, relayKey: "")
        ))
    }

    func testPausedAndUntrustedStateChangingMessagesAreRejected() {
        for kind in [SyncMessageKind.input, .session, .pair] {
            XCTAssertFalse(ProtocolSecurity.permits(
                kind, enabled: false, trusted: true, pairingMode: true
            ))
            XCTAssertFalse(ProtocolSecurity.permits(
                kind, enabled: true, trusted: false, pairingMode: true
            ))
        }
        XCTAssertFalse(ProtocolSecurity.permits(
            .pair, enabled: true, trusted: true, pairingMode: false
        ))
        XCTAssertTrue(ProtocolSecurity.permits(
            .input, enabled: true, trusted: true, pairingMode: false
        ))
    }

    func testSemanticVersionComparisonAndMalformedVersions() {
        XCTAssertTrue(UpdateChecker.version("1.2.10", isNewerThan: "1.2.9"))
        XCTAssertTrue(UpdateChecker.version("v2.0.0", isNewerThan: "1.99.99"))
        XCTAssertFalse(UpdateChecker.version("autocd.autocd.1", isNewerThan: "1.0.1"))
        XCTAssertFalse(UpdateChecker.version("1.2", isNewerThan: "1.0.1"))
        XCTAssertNil(SemanticVersion("v1.2.3-beta"))
    }
}
