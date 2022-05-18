import XCTest
@testable import novawallet

class BlockTimeEstimationServiceTests: XCTestCase {
    func testBlockTimeEstimation() {
        let chainId = "401a1f9dca3da46f5c4091016c8a2f26dcea05865116b286f60f668207d1474b"

        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            XCTFail("Missing connection or runtime")
            return
        }

        let repository = SubstrateRepositoryFactory(storageFacade: storageFacade).createChainStorageItemRepository()

        let blockTimeEstimationService = BlockTimeEstimationService(
            chainId: chainId,
            connection: connection,
            runtimeService: runtimeService,
            repository: repository,
            eventCenter: EventCenter.shared,
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )

        blockTimeEstimationService.setup()

        let unresolved = XCTestExpectation()
        wait(for: [unresolved], timeout: TimeInterval.infinity)

        XCTAssert(blockTimeEstimationService.isActive)
    }
}
