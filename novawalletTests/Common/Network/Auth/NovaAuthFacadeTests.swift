import XCTest
import Cuckoo
import NovaAuth
import Operation_iOS
@testable import novawallet

final class NovaAuthFacadeTests: XCTestCase {
    func testAvailabilityReadAndObserverRegistrationDoNotWaitForAnActivatingAdoption() {
        let url = URL(string: "https://first.test")!
        let config = GlobalConfig(multiStakingApiUrl: url, multisigsApiUrl: url, proxyApiUrl: url, infraUrl: url)
        let configProvider = MockGlobalConfigProviding()
        let client = MockNovaAuthClientProtocol()
        stub(configProvider) { stub in
            when(stub.addSnapshotObserver(any(), closure: any())).thenDoNothing()
            when(stub.createConfigSnapshotWrapper()).thenReturn(.createWithResult(.init(config: config, revision: 1)))
        }
        stub(client) { stub in
            when(stub.isSupported.get).thenReturn(true)
        }
        let activating = DispatchSemaphore(value: 0)
        let releaseActivation = DispatchSemaphore(value: 0)
        let provider = NovaAuthFacade(
            configProvider: configProvider,
            client: client,
            contextInvalidationID: { UUID() },
            activate: { _ in
                activating.signal()
                _ = releaseActivation.wait(timeout: .now() + 5)
                throw NovaAuthError.unsupported
            }
        )
        let adoptionQueue = OperationQueue()
        adoptionQueue.addOperations(provider.createEndpointWrapper().allOperations, waitUntilFinished: false)
        XCTAssertEqual(activating.wait(timeout: .now() + 5), .success)

        let registered = DispatchSemaphore(value: 0)
        let notified = expectation(description: "observer registered during the adoption notified")
        DispatchQueue.global().async {
            _ = provider.endpointAvailability
            _ = provider.addAvailabilityObserver(self) { _ in notified.fulfill() }
            registered.signal()
        }

        XCTAssertEqual(registered.wait(timeout: .now() + 2), .success)
        releaseActivation.signal()
        wait(for: [notified], timeout: 5)
        adoptionQueue.waitUntilAllOperationsAreFinished()
    }
}
