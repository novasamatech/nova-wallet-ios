import XCTest
@testable import NovaAppAttest
import Operation_iOS
import DeviceCheck

final class AppAttestServiceTests: XCTestCase {
    private struct UnknownFailure: Error {}

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func run<T>(_ operation: BaseOperation<T>) throws -> T {
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractNoCancellableResultData()
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
        let device = makeDevice()
        device.generateAssertionResult = .failure(error)
        return device
    }

    private func makeDevice(failingAttestationWith error: Error) -> DeviceCheckAttestingSpy {
        let device = makeDevice()
        device.attestKeyResult = .failure(error)
        return device
    }

    private func assertAttestation(
        failsWith expected: AppAttestServiceError,
        whenDeviceReports error: Error,
        line: UInt = #line
    ) {
        let service = AppAttestService(service: makeDevice(failingAttestationWith: error))

        XCTAssertThrowsError(
            try run(service.createAttestationWrapper(using: "k1") { _ in Data() })
        ) { thrown in
            assertSameCase(thrown, expected, line: line)
        }
    }

    private func assertAssertion(
        failsWith expected: AppAttestServiceError,
        whenDeviceReports error: Error,
        line: UInt = #line
    ) {
        let service = AppAttestService(service: makeDevice(failingAssertionWith: error))

        XCTAssertThrowsError(
            try run(service.createAssertionWrapper(keyId: "k1", clientData: { Data() }))
        ) { thrown in
            assertSameCase(thrown, expected, line: line)
        }
    }

    private func assertSameCase(_ thrown: Error, _ expected: AppAttestServiceError, line: UInt) {
        guard let actual = thrown as? AppAttestServiceError else {
            return XCTFail("expected \(expected), got \(thrown)", line: line)
        }

        switch (actual, expected) {
        case (.invalidKeyId, .invalidKeyId),
             (.serviceUnavailable, .serviceUnavailable),
             (.attestationGeneric, .attestationGeneric),
             (.assertionGeneric, .assertionGeneric),
             (.keyIdGeneration, .keyIdGeneration):
            break
        default:
            XCTFail("expected \(expected), got \(actual)", line: line)
        }
    }

    func testGeneratedKeyIdIsReturnedByTheKeyGenerationOperation() throws {
        let device = makeDevice()
        let service = AppAttestService(service: device)

        let keyId = try run(service.createKeyGenerationOperation())

        XCTAssertEqual(keyId, "generated-key-id")
        XCTAssertEqual(device.generateKeyCallCount, 1)
    }

    func testKeyGenerationFailureMapsToKeyIdGeneration() {
        let device = makeDevice()
        device.generateKeyResult = .failure(UnknownFailure())
        let service = AppAttestService(service: device)

        XCTAssertThrowsError(try run(service.createKeyGenerationOperation())) { error in
            assertSameCase(error, .keyIdGeneration(nil), line: #line)
        }
    }

    func testAttestationUsesTheKeyIdItWasGiven() throws {
        let device = makeDevice()
        let service = AppAttestService(service: device)

        var seenKeyId: String?
        let result = try run(service.createAttestationWrapper(using: "persisted-key-id") { keyId in
            seenKeyId = keyId
            return Data("challenge|client|\(keyId)".utf8)
        })

        XCTAssertEqual(seenKeyId, "persisted-key-id")
        XCTAssertEqual(result.keyId, "persisted-key-id")
        XCTAssertEqual(device.attestationKeyIds, ["persisted-key-id"])
        XCTAssertEqual(device.generateKeyCallCount, 0)
    }

    func testClientDataIsHashedWithSha256BeforeReachingDeviceCheck() throws {
        let device = makeDevice()
        let service = AppAttestService(service: device)
        let clientData = Data("the exact client data".utf8)

        _ = try run(service.createAssertionWrapper(keyId: "k", clientData: { clientData }))

        XCTAssertEqual(device.assertionClientDataHashes, [clientData.sha256()])
    }

    func testAttestationServerUnavailableMapsToServiceUnavailable() {
        assertAttestation(failsWith: .serviceUnavailable, whenDeviceReports: DCError(.serverUnavailable))
    }

    func testAttestationInvalidKeyMapsToInvalidKeyId() {
        assertAttestation(failsWith: .invalidKeyId, whenDeviceReports: DCError(.invalidKey))
    }

    func testAttestationInvalidInputMapsToInvalidKeyId() {
        assertAttestation(failsWith: .invalidKeyId, whenDeviceReports: DCError(.invalidInput))
    }

    func testAttestationFeatureUnsupportedMapsToAttestationGeneric() {
        assertAttestation(failsWith: .attestationGeneric(nil), whenDeviceReports: DCError(.featureUnsupported))
    }

    func testAttestationUnknownSystemFailureMapsToAttestationGeneric() {
        assertAttestation(failsWith: .attestationGeneric(nil), whenDeviceReports: DCError(.unknownSystemFailure))
    }

    func testAttestationNonDeviceCheckErrorMapsToAttestationGeneric() {
        assertAttestation(failsWith: .attestationGeneric(nil), whenDeviceReports: UnknownFailure())
    }

    func testAssertionServerUnavailableMapsToServiceUnavailable() {
        assertAssertion(failsWith: .serviceUnavailable, whenDeviceReports: DCError(.serverUnavailable))
    }

    func testAssertionInvalidKeyMapsToInvalidKeyId() {
        assertAssertion(failsWith: .invalidKeyId, whenDeviceReports: DCError(.invalidKey))
    }

    func testAssertionInvalidInputMapsToInvalidKeyId() {
        assertAssertion(failsWith: .invalidKeyId, whenDeviceReports: DCError(.invalidInput))
    }

    func testAssertionFeatureUnsupportedMapsToAssertionGeneric() {
        assertAssertion(failsWith: .assertionGeneric(nil), whenDeviceReports: DCError(.featureUnsupported))
    }

    func testAssertionUnknownSystemFailureMapsToAssertionGeneric() {
        assertAssertion(failsWith: .assertionGeneric(nil), whenDeviceReports: DCError(.unknownSystemFailure))
    }

    func testAssertionNonDeviceCheckErrorMapsToAssertionGeneric() {
        assertAssertion(failsWith: .assertionGeneric(nil), whenDeviceReports: UnknownFailure())
    }
}
