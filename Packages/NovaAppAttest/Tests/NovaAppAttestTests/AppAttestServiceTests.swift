import XCTest
@testable import NovaAppAttest
import Operation_iOS
import DeviceCheck

final class AppAttestServiceTests: XCTestCase {
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func makeDevice() -> DeviceCheckAttestingSpy {
        let device = DeviceCheckAttestingSpy()
        device.isSupported = true
        device.generateKeyResult = .success("generated-key-id")
        device.attestKeyResult = .success(Data("attestation".utf8))
        device.generateAssertionResult = .success(Data("assertion".utf8))
        return device
    }

    private func makeDevice(failingAssertionWith error: Error) -> DeviceCheckAttestingSpy {
        let device = DeviceCheckAttestingSpy()
        device.isSupported = true
        device.generateAssertionResult = .failure(error)
        return device
    }

    func testAttestationClientDataReceivesTheGeneratedKeyId() throws {
        let device = makeDevice()
        let service = AppAttestService(service: device)

        var seenKeyId: String?
        let result = try run(service.createAttestationWrapper(using: nil) { keyId in
            seenKeyId = keyId
            return Data("challenge|client|\(keyId)".utf8)
        })

        XCTAssertEqual(seenKeyId, "generated-key-id")
        XCTAssertEqual(result.keyId, "generated-key-id")
        XCTAssertEqual(result.attestation, Data("attestation".utf8))
    }

    func testExistingKeyIdIsReusedWithoutGeneratingANewOne() throws {
        let device = makeDevice()
        let service = AppAttestService(service: device)

        let result = try run(service.createAttestationWrapper(using: "existing-key") { _ in Data() })

        XCTAssertEqual(result.keyId, "existing-key")
        XCTAssertEqual(device.generateKeyCallCount, 0)
    }

    func testClientDataIsHashedWithSha256BeforeReachingDeviceCheck() throws {
        let device = makeDevice()
        let service = AppAttestService(service: device)
        let clientData = Data("the exact client data".utf8)

        _ = try run(service.createAssertionWrapper(keyId: "k", clientData: { clientData }))

        XCTAssertEqual(device.assertionClientDataHashes, [clientData.sha256()])
    }

    func testInvalidKeyDCErrorMapsToInvalidKeyId() {
        let device = makeDevice(failingAssertionWith: DCError(.invalidKey))
        let service = AppAttestService(service: device)

        XCTAssertThrowsError(try run(service.createAssertionWrapper(keyId: "k", clientData: { Data() }))) { error in
            guard case .invalidKeyId? = error as? AppAttestServiceError else {
                return XCTFail("Expected invalidKeyId, got \(error)")
            }
        }
    }

    func testServerUnavailableDCErrorMapsToServiceUnavailable() {
        let device = makeDevice(failingAssertionWith: DCError(.serverUnavailable))
        let service = AppAttestService(service: device)

        XCTAssertThrowsError(try run(service.createAssertionWrapper(keyId: "k", clientData: { Data() }))) { error in
            guard case .serviceUnavailable? = error as? AppAttestServiceError else {
                return XCTFail("Expected serviceUnavailable, got \(error)")
            }
        }
    }
}
