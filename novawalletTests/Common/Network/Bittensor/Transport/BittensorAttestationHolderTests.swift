import XCTest
@testable import novawallet
import Cuckoo
import NovaAppAttest
import Operation_iOS

final class BittensorAttestationHolderTests: XCTestCase {
    func testUnitTestProcessFailsUnsupportedDeviceWithoutResolvingTheSharedProvider() {
        let attestationHolder = MockBackendAttestationHolderProtocol()
        let appAttest = MockAppAttestServiceProtocol()

        stub(appAttest) { stub in
            when(stub.isSupported.get).thenReturn(true)
        }

        let holder = BittensorAttestationHolder(
            attestationHolder: attestationHolder,
            appAttest: appAttest,
            appIdentity: AppAttestAppIdentity(appId: "PREFIX.io.novafoundation.novawallet.dev", environment: "development"),
            isUnitTesting: true
        )

        let wrapper = holder.createEndpointWrapper()

        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        XCTAssertThrowsError(try wrapper.targetOperation.extractNoCancellableResultData()) { error in
            guard case .unsupportedDevice = error as? BittensorApiError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        verify(attestationHolder, never()).createEndpointWrapper()
    }
}
