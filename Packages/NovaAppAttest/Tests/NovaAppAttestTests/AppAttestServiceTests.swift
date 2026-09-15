import XCTest
@testable import NovaAppAttest
import Operation_iOS
import DeviceCheck

final class AppAttestServiceTests: XCTestCase {
    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }

    private func assertAttestation(_ deviceError: Error, maps: AppAttestServiceError, line: UInt = #line) {
        let device = DeviceCheckAttestingSpy()
        device.attestKeyResult = .failure(deviceError)
        let service = AppAttestService(service: device)

        XCTAssertThrowsError(try run(service.createAttestationWrapper(using: "k1") { _ in Data() })) { error in
            XCTAssertEqual("\(error)", "\(maps)", line: line)
        }
    }

    func testHashesAssertionClientData() throws {
        let device = DeviceCheckAttestingSpy()
        let service = AppAttestService(service: device)
        let clientData = Data("client-data".utf8)

        _ = try run(service.createAssertionWrapper(keyId: "k", clientData: { clientData }))

        XCTAssertEqual(device.assertionClientDataHashes, [clientData.sha256()])
    }

    func testMapsInvalidKeyError() {
        assertAttestation(DCError(.invalidKey), maps: .invalidKeyId)
    }

    func testMapsServerUnavailableError() {
        assertAttestation(DCError(.serverUnavailable), maps: .serviceUnavailable)
    }
}
