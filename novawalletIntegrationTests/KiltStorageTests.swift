import XCTest
@testable import novawallet
import SubstrateSdk
import RobinHood
import IrohaCrypto
import BigInt
import xxHash_Swift
import SoraKeystore
import SoraFoundation

final class KiltStorageTests: XCTestCase {
    
    func testKiltNameService() throws {
        let chainId = "411f057b9107718c9624d6aa4a3f23c1653898297f3d4d529d9bb6511a39dd21"
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        
        let queue = OperationQueue()
        let operationFactory = KiltWeb3NamesOperationFactory(operationQueue: queue)
  
        let wrapper = operationFactory.createOwnerOperation(
            name: "john_doe",
            connection: connection,
            runtimeService: runtimeService)
        
        queue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: true
        )
        
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        XCTAssertNotNil(result)
    }
    
    func testKiltServices() throws {
        let chainId = "411f057b9107718c9624d6aa4a3f23c1653898297f3d4d529d9bb6511a39dd21"
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        
        let queue = OperationQueue()
        let operationFactory = KiltWeb3NamesOperationFactory(operationQueue: queue)
        let accountId = try! "4pZGzLSybfMsxB1DcpFNYmnqFv5QihbFb1zuSuuATqjRQv2g".toAccountId()
        
        let wrapper = operationFactory.createServicesOperation(owner: accountId,
                                                               connection: connection,
                                                               runtimeService: runtimeService)
        
        queue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: true
        )
        
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        XCTAssertTrue(!result.isEmpty)
    }
}
