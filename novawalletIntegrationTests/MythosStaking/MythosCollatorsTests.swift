import XCTest
@testable import novawallet

final class MythosCollatorsTests: XCTestCase {
    static let chainId = "15f6788bcf1d1a3b7e1c36074584e1a3f3d07e0a46e362a102c3c3df1a93669f"
    
    func testFetchCollators() {
        // given
        
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let operationQueue = OperationQueue()
        
        let service = MythosCollatorService(
            chainId: Self.chainId,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
        
        // when
        
        service.setup()
        
        let operation = service.fetchInfoOperation()
        
        // then
        
        operationQueue.addOperations([operation], waitUntilFinished: true)
        
        do {
            let collators = try operation.extractNoCancellableResultData()
            
            Logger.shared.debug("Collators: \(collators)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
