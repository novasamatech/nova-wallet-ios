import XCTest
@testable import novawallet
import Operation_iOS

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
        let transfers = try fetchXcmTransfers()
    }
    
    private func fetchXcmTransfers() throws -> XcmTransfers {
        let operationQueue = OperationQueue()
        
        let xcmSyncService = XcmTransfersSyncService(config: ApplicationConfig.shared, operationQueue: operationQueue)
        
        let fetchOperation = AsyncClosureOperation<XcmTransfers> { completionClosure in
            xcmSyncService.notificationCallback = { [weak xcmSyncService] result in
                xcmSyncService?.throttle()
                completionClosure(result)
            }
        }
        
        xcmSyncService.setup()
        
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)
        
        return try fetchOperation.extractNoCancellableResultData()
    }
}
