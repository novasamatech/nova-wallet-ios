import XCTest
import Operation_iOS
import NovaAuth
@testable import novawallet

private final class AuthConfigProvider: GlobalConfigProviding {
    private let snapshot: GlobalConfigSnapshot = {
        let url = URL(string: "https://first.test")!
        let config = GlobalConfig(multiStakingApiUrl: url, multisigsApiUrl: url, proxyApiUrl: url, infraUrl: url)
        return GlobalConfigSnapshot(config: config, revision: 1)
    }()

    func addSnapshotObserver(_: AnyObject, closure _: @escaping (GlobalConfigSnapshot) -> Void) {}
    func createConfigSnapshotWrapper() -> CompoundOperationWrapper<GlobalConfigSnapshot> { .createWithResult(snapshot) }
    func createConfigWrapper() -> CompoundOperationWrapper<GlobalConfig> { .createWithResult(snapshot.config) }
}

final class NovaAuthFacadeTests: XCTestCase {
    func testRevisionReadAndObserverRegistrationDoNotWaitForAnActivatingAdoption() throws {
        let harness = try HostAuthHarness(protocolClass: HostAuthURLProtocol.self)
        let activating = DispatchSemaphore(value: 0)
        let releaseActivation = DispatchSemaphore(value: 0)
        let provider = NovaAuthFacade(
            configProvider: AuthConfigProvider(),
            client: harness.client,
            contextInvalidationID: { UUID() },
            activate: { _ in
                activating.signal()
                _ = releaseActivation.wait(timeout: .now() + 5)
                throw NovaAuthError.unsupported
            }
        )
        let transport = BittensorAuthorizedTransport(provider: provider, operationQueue: OperationQueue())
        let adoptionQueue = OperationQueue()
        adoptionQueue.addOperations(provider.createEndpointWrapper().allOperations, waitUntilFinished: false)
        XCTAssertEqual(activating.wait(timeout: .now() + 5), .success)

        let revisionRead = DispatchSemaphore(value: 0)
        let notified = expectation(description: "observers registered during the adoption notified")
        notified.expectedFulfillmentCount = 2
        DispatchQueue.global().async {
            _ = transport.invalidationRevision
            _ = transport.addInvalidationObserver(self) { _ in notified.fulfill() }
            provider.addContextObserver(self) { notified.fulfill() }
            revisionRead.signal()
        }

        XCTAssertEqual(revisionRead.wait(timeout: .now() + 2), .success)
        releaseActivation.signal()
        let adopted = expectation(description: "adoption finished")
        adoptionQueue.addBarrierBlock { adopted.fulfill() }
        wait(for: [notified, adopted], timeout: 5)
    }
}
