import XCTest
@testable import novawallet
import Operation_iOS
import DeviceCheck
import Cuckoo

final class AppAttestServiceTests: XCTestCase {
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func makeDevice() -> MockDeviceCheckAttesting {
        let device = MockDeviceCheckAttesting()
        stub(device) { stub in
            when(stub.isSupported.get).thenReturn(true)
            when(stub.generateKey(completionHandler: any())).then { completion in
                completion("generated-key-id", nil)
            }
            when(stub.attestKey(any(), clientDataHash: any(), completionHandler: any()))
                .then { _, _, completion in completion(Data("attestation".utf8), nil) }
            when(stub.generateAssertion(any(), clientDataHash: any(), completionHandler: any()))
                .then { _, _, completion in completion(Data("assertion".utf8), nil) }
        }
        return device
    }

    private func makeDevice(failingAssertionWith error: Error) -> MockDeviceCheckAttesting {
        let device = MockDeviceCheckAttesting()
        stub(device) { stub in
            when(stub.isSupported.get).thenReturn(true)
            when(stub.generateAssertion(any(), clientDataHash: any(), completionHandler: any()))
                .then { _, _, completion in completion(nil, error) }
        }
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
        verify(device, never()).generateKey(completionHandler: any())
    }

    func testClientDataIsHashedWithSha256BeforeReachingDeviceCheck() throws {
        let device = makeDevice()
        let service = AppAttestService(service: device)
        let clientData = Data("the exact client data".utf8)

        _ = try run(service.createAssertionWrapper(keyId: "k", clientData: { clientData }))

        let captor = ArgumentCaptor<Data>()
        verify(device).generateAssertion(any(), clientDataHash: captor.capture(), completionHandler: any())
        XCTAssertEqual(captor.value, clientData.sha256())
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
