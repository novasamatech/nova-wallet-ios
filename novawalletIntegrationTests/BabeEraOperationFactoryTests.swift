import XCTest
import Operation_iOS
import SubstrateSdk
@testable import novawallet

class EraCountdownOperationFactoryTests: XCTestCase {
    func testService() {
        let operationManager = OperationManagerFacade.sharedManager

        let chainId = KnowChainId.kusama
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: SubstrateStorageTestFacade())
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let factory = BabeEraOperationFactory(storageRequestFactory: storageRequestFactory)

        let timeExpectation = XCTestExpectation()
        let operationWrapper = factory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )
        operationWrapper.targetOperation.completionBlock = {
            do {
                let eraCountdown = try operationWrapper.targetOperation.extractNoCancellableResultData()
                Logger.shared.info(
                    "Estimating era completion time (in seconds): \(eraCountdown.timeIntervalTillNextActiveEraStart())"
                )
                timeExpectation.fulfill()
            } catch {
                XCTFail(error.localizedDescription)
            }
        }

        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)

        wait(for: [timeExpectation], timeout: 20)
    }
}
