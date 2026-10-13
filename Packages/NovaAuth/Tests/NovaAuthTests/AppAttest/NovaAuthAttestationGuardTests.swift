import XCTest
@testable import NovaAuth

final class NovaAuthAttestationGuardTests: XCTestCase {
    func testFailedPrecallGuardReleasesLeaseWithoutNativeInvocation() throws {
        let service = CountingDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service)
        let wrapper = adapter.createAttestationWrapper(
            keyID: FoundationFixture.keyID,
            clientDataHash: Data(repeating: 1, count: 32),
            beforeAttest: { throw NovaAuthError.userActionRequired }
        )
        XCTAssertThrowsError(try executeFoundation(wrapper)) {
            XCTAssertEqual($0 as? NovaAuthError, .userActionRequired)
        }
        XCTAssertEqual(service.attestationCalls, 0)
        XCTAssertFalse(adapter.isBusy(keyID: FoundationFixture.keyID))
        _ = try executeFoundation(adapter.createAttestationWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: Data(repeating: 2, count: 32), beforeAttest: {}
        ))
        XCTAssertEqual(service.attestationCalls, 1)
    }
}

final class CountingDeviceCheck: NovaAuthDeviceCheckProtocol {
    private let lock = NSLock()
    private var keys = 0
    private var attestations = 0
    var onAttestation: (() -> Void)?
    var isSupported: Bool { true }
    var keyCalls: Int { lock.novaAuthLocked { keys } }
    var attestationCalls: Int { lock.novaAuthLocked { attestations } }

    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
        lock.novaAuthLocked { keys += 1 }
        completionHandler(Data(repeating: 9, count: 32).base64EncodedString(), nil)
    }

    func attestKey(_: String, clientDataHash _: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        lock.novaAuthLocked { attestations += 1 }
        onAttestation?()
        completionHandler(Data([1, 2, 3]), nil)
    }

    func generateAssertion(_: String, clientDataHash _: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        completionHandler(Data([4, 5, 6]), nil)
    }
}
