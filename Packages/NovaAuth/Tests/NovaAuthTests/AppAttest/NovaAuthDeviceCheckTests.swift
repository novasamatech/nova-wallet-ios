import XCTest
import DeviceCheck
import Operation_iOS
@testable import NovaAuth

final class NovaAuthDeviceCheckTests: XCTestCase {
    func testAppleReceivesDigestDirectlyForBothProofTypes() throws {
        let service = FoundationDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service)
        let digest = try XCTUnwrap(Data(base64Encoded: "WYm06t980FQu63RyLu0EFoaykR8M+b8bgidQ4UZcKTY="))
        _ = try executeFoundation(adapter.createAttestationWrapper(keyID: FoundationFixture.keyID, clientDataHash: digest))
        XCTAssertEqual(service.hashes, [digest])
        _ = try executeFoundation(adapter.createAssertionWrapper(keyID: FoundationFixture.keyID, clientDataHash: digest))
        XCTAssertEqual(service.hashes, [digest, digest])
        XCTAssertEqual(try executeFoundation(adapter.createKeyWrapper()), FoundationFixture.keyID)
        XCTAssertThrowsError(try executeFoundation(adapter.createAssertionWrapper(keyID: FoundationFixture.keyID, clientDataHash: Data())))
        XCTAssertEqual(service.hashes.count, 2)
    }

    func testExpectedProviderErrorsAreSanitized() throws {
        let cases: [(DCError.Code, NovaAuthAppAttestError)] = [(.serverUnavailable, .serverUnavailable), (.invalidKey, .invalidKey),
                                                               (.invalidInput, .invalidKey), (.featureUnsupported, .unsupported)]
        for (code, expected) in cases {
            let service = FoundationDeviceCheck()
            service.error = NSError(
                domain: DCError.errorDomain,
                code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "DO-NOT-EXPOSE-PROVIDER-DETAILS"]
            )
            let adapter = NovaAuthDeviceCheckService(service: service)
            XCTAssertThrowsError(try executeFoundation(adapter.createKeyWrapper())) { error in
                XCTAssertEqual(String(describing: error), String(describing: expected))
                XCTAssertFalse(String(reflecting: error).contains("DO-NOT-EXPOSE"))
            }
        }
    }

    func testUnsupportedNeverCallsAppleAndHungAppleFinishesOnce() throws {
        let unsupported = FoundationDeviceCheck()
        unsupported.isSupported = false
        XCTAssertThrowsError(try executeFoundation(NovaAuthDeviceCheckService(service: unsupported).createKeyWrapper()))
        XCTAssertEqual(unsupported.keyCalls, 0)
        let hung = FoundationDeviceCheck()
        hung.hang = true
        let adapter = NovaAuthDeviceCheckService(service: hung, timeout: 0.02)
        let wrapper = adapter.createKeyWrapper()
        XCTAssertThrowsError(try executeFoundation(wrapper)) { XCTAssertEqual(String(describing: $0), "timedOut") }
        hung.keyCompletion?(FoundationFixture.keyID, nil)
        XCTAssertThrowsError(try XCTUnwrap(wrapper.targetOperation.result).get()) {
            XCTAssertEqual(String(describing: $0), "timedOut")
        }
    }
}

private final class FoundationDeviceCheck: NovaAuthDeviceCheckProtocol {
    var isSupported = true
    var keyCalls = 0
    var hashes: [Data] = []
    var error: Error?
    var hang = false
    var keyCompletion: ((String?, Error?) -> Void)?
    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
        keyCalls += 1
        keyCompletion = completionHandler
        if !hang { completionHandler(error == nil ? FoundationFixture.keyID : nil, error) }
    }

    func attestKey(_: String, clientDataHash: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        hashes.append(clientDataHash)
        completionHandler(error == nil ? Data([1, 2, 3]) : nil, error)
    }

    func generateAssertion(_: String, clientDataHash: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        hashes.append(clientDataHash)
        completionHandler(error == nil ? Data([4, 5, 6]) : nil, error)
    }
}
