import XCTest
@testable import novawallet

final class DryRunBasedFeeTests: XCTestCase {
    func testDryRunTransferAssets() throws {
        // given
        
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)
        
        let operationQueue = OperationQueue()
        let dryRunOperationFactory = DryRunOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
        
        let polkadot = try chainRegistry.getChainOrError(for: KnowChainId.polkadot)
        let hydration = try chainRegistry.getChainOrError(for: KnowChainId.hydra)
    }
}
