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

    func testTimedOutAssertionKeepsKeyLeasedUntilActualCallback() throws {
        let service = DelayedDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service, timeout: 0.02)
        let digest = Data(repeating: 1, count: 32)
        XCTAssertFalse(adapter.isBusy(keyID: FoundationFixture.keyID))
        var first = adapter.createAssertionWrapper(keyID: FoundationFixture.keyID, clientDataHash: digest)
        XCTAssertThrowsError(try executeFoundation(first)) { XCTAssertEqual(String(describing: $0), "timedOut") }
        XCTAssertTrue(adapter.isBusy(keyID: FoundationFixture.keyID))
        let lateCallback = try service.callback(at: 0)

        XCTAssertThrowsError(try executeFoundation(
            adapter.createAssertionWrapper(keyID: FoundationFixture.keyID, clientDataHash: digest)
        )) { XCTAssertEqual(String(describing: $0), "serverUnavailable") }
        XCTAssertEqual(service.proofCount, 1)
        XCTAssertThrowsError(try XCTUnwrap(first.targetOperation.result).get()) {
            XCTAssertEqual(String(describing: $0), "timedOut")
        }

        first = .createWithResult(Data())
        lateCallback(Data([4, 5, 6]), nil)
        XCTAssertFalse(adapter.isBusy(keyID: FoundationFixture.keyID))
        service.automaticResponse = Data([7, 8, 9])
        XCTAssertEqual(try executeFoundation(
            adapter.createAssertionWrapper(keyID: FoundationFixture.keyID, clientDataHash: digest)
        ), Data([7, 8, 9]))
        XCTAssertEqual(service.proofCount, 2)
    }

    func testCancellationKeepsProofLeaseAcrossAttestationAndAssertion() throws {
        let service = DelayedDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service)
        let started = expectation(description: "Apple call started")
        service.onProof = { started.fulfill() }
        let first = adapter.createAttestationWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: Data(repeating: 1, count: 32)
        )
        let finished = expectation(description: "cancelled operation finished")
        first.targetOperation.completionBlock = { finished.fulfill() }
        let queue = OperationQueue()
        queue.addOperations(first.allOperations, waitUntilFinished: false)
        wait(for: [started], timeout: 3)
        service.onProof = nil
        first.cancel()
        wait(for: [finished], timeout: 3)
        XCTAssertTrue(adapter.isBusy(keyID: FoundationFixture.keyID))

        XCTAssertThrowsError(try executeFoundation(adapter.createAssertionWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: Data(repeating: 2, count: 32)
        ))) { XCTAssertEqual(String(describing: $0), "serverUnavailable") }
        XCTAssertEqual(service.proofCount, 1)

        try service.callback(at: 0)(nil, NSError(domain: DCError.errorDomain, code: DCError.Code.serverUnavailable.rawValue))
        XCTAssertFalse(adapter.isBusy(keyID: FoundationFixture.keyID))
        service.automaticResponse = Data([4, 5, 6])
        XCTAssertEqual(try executeFoundation(adapter.createAssertionWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: Data(repeating: 2, count: 32)
        )), Data([4, 5, 6]))
        XCTAssertEqual(service.proofCount, 2)
    }

    func testUnfinishedProofDoesNotBlockAnotherKey() throws {
        let service = DelayedDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service, timeout: 0.02)
        let digest = Data(repeating: 1, count: 32)
        XCTAssertThrowsError(try executeFoundation(adapter.createAssertionWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: digest
        ))) { XCTAssertEqual(String(describing: $0), "timedOut") }

        service.automaticResponse = Data([4, 5, 6])
        let otherKey = Data(repeating: 99, count: 32).base64EncodedString()
        XCTAssertTrue(adapter.isBusy(keyID: FoundationFixture.keyID))
        XCTAssertFalse(adapter.isBusy(keyID: otherKey))
        XCTAssertEqual(try executeFoundation(adapter.createAttestationWrapper(
            keyID: otherKey, clientDataHash: digest
        )), Data([4, 5, 6]))
        XCTAssertThrowsError(try executeFoundation(adapter.createAssertionWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: digest
        ))) { XCTAssertEqual(String(describing: $0), "serverUnavailable") }
        XCTAssertEqual(service.proofCount, 2)
        try service.callback(at: 0)(Data([4, 5, 6]), nil)
    }

    func testDuplicateOldCallbackCannotReleaseNewCallLease() throws {
        let service = DelayedDeviceCheck()
        let adapter = NovaAuthDeviceCheckService(service: service, timeout: 0.02)
        let digest = Data(repeating: 1, count: 32)
        XCTAssertThrowsError(try executeFoundation(adapter.createAssertionWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: digest
        )))
        let firstCallback = try service.callback(at: 0)
        firstCallback(Data([1]), nil)
        XCTAssertThrowsError(try executeFoundation(adapter.createAssertionWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: digest
        ))) { XCTAssertEqual(String(describing: $0), "timedOut") }

        firstCallback(Data([1]), nil)
        XCTAssertThrowsError(try executeFoundation(adapter.createAssertionWrapper(
            keyID: FoundationFixture.keyID, clientDataHash: digest
        ))) { XCTAssertEqual(String(describing: $0), "serverUnavailable") }
        XCTAssertEqual(service.proofCount, 2)
        try service.callback(at: 1)(Data([2]), nil)
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

final class DelayedDeviceCheck: NovaAuthDeviceCheckProtocol {
    private let lock = NSLock()
    private var callbacks: [(Data?, Error?) -> Void] = []
    private var response: Data?
    private var proofObserver: (() -> Void)?

    var isSupported: Bool { true }
    var proofCount: Int { lock.novaAuthLocked { callbacks.count } }
    var automaticResponse: Data? {
        get { lock.novaAuthLocked { response } }
        set { lock.novaAuthLocked { response = newValue } }
    }

    var onProof: (() -> Void)? {
        get { lock.novaAuthLocked { proofObserver } }
        set { lock.novaAuthLocked { proofObserver = newValue } }
    }

    func callback(at index: Int) throws -> (Data?, Error?) -> Void {
        try lock.novaAuthLocked {
            try XCTUnwrap(callbacks.indices.contains(index) ? callbacks[index] : nil)
        }
    }

    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
        completionHandler(FoundationFixture.keyID, nil)
    }

    func attestKey(_: String, clientDataHash _: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        startProof(completionHandler)
    }

    func generateAssertion(_: String, clientDataHash _: Data, completionHandler: @escaping (Data?, Error?) -> Void) {
        startProof(completionHandler)
    }

    private func startProof(_ completion: @escaping (Data?, Error?) -> Void) {
        let snapshot = lock.novaAuthLocked { () -> (Data?, (() -> Void)?) in
            callbacks.append(completion)
            return (response, proofObserver)
        }
        snapshot.1?()
        if let data = snapshot.0 { completion(data, nil) }
    }
}
