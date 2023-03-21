import XCTest
@testable import novawallet
import SubstrateSdk
import RobinHood
import IrohaCrypto
import BigInt
import xxHash_Swift
import SoraKeystore
import SoraFoundation

final class Web3NamesOperationFactoryTests: XCTestCase {
    
    func testKiltNameService_WhenNameNotFoundThanResultIsNil() throws {
        let chainId = "411f057b9107718c9624d6aa4a3f23c1653898297f3d4d529d9bb6511a39dd21"
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        
        let queue = OperationQueue()
        let operationFactory = KiltWeb3NamesOperationFactory(operationQueue: queue)
        
        let wrapper = operationFactory.searchWeb3NameWrapper(name: "53898297f3d4d529d9bb6511a39d",
                                                             service: KnownServices.transferAssetRecipient,
                                                             connection: connection,
                                                             runtimeService: runtimeService)
        
        queue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: true
        )
        
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        XCTAssertTrue(result == nil)
    }
    
    func testKiltNameService_WhenNameNotFoundAndHasNoTransferServiceThanResultContainsAccount() throws {
        let chainId = "411f057b9107718c9624d6aa4a3f23c1653898297f3d4d529d9bb6511a39dd21"
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        
        let queue = OperationQueue()
        let operationFactory = KiltWeb3NamesOperationFactory(operationQueue: queue)
        
        let wrapper = operationFactory.searchWeb3NameWrapper(name: "john_doe",
                                                             service: KnownServices.transferAssetRecipient,
                                                             connection: connection,
                                                             runtimeService: runtimeService)
        
        queue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: true
        )
        
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        XCTAssertTrue(result?.owner != nil)
    }
    
    func testKiltServices_WhenNameAndServiceExistThanResultIsCorrect() throws {
        let chainId = "411f057b9107718c9624d6aa4a3f23c1653898297f3d4d529d9bb6511a39dd21"
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let connection = chainRegistry.getConnection(for: chainId)!
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainId)!
        
        let queue = OperationQueue()
        let operationFactory = KiltWeb3NamesOperationFactory(operationQueue: queue)
        
        let wrapper = operationFactory.searchWeb3NameWrapper(name: "john_doe",
                                                             service: "KiltPublishedCredentialCollectionV1",
                                                             connection: connection,
                                                             runtimeService: runtimeService)
        
        queue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: true
        )
        
        let result = try wrapper.targetOperation.extractNoCancellableResultData()
        XCTAssertNotNil(result)
        XCTAssertTrue(!result!.serviceURLs.isEmpty)
    }
}

