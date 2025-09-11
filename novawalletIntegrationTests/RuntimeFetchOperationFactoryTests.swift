import XCTest
@testable import novawallet
import Operation_iOS
import SubstrateSdk

final class RuntimeFetchOperationFactoryTests: XCTestCase {
    
    func testPolkadot() {
        do {
            let metadata = try performTestFetchLatestMetadata(for: KnowChainId.polkadot)
            Logger.shared.info("Metadata opaque: \(metadata.isOpaque)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testEdgewareNotOpaque() {
        do {
            let metadata = try performTestFetchLatestMetadata(for: KnowChainId.edgeware)
            Logger.shared.info("Metadata opaque: \(metadata.isOpaque)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testBasiliskOpaque() {
        do {
            let rawMetadata = try performTestFetchLatestMetadata(for: "a85cfb9b9fd4d622a5b28289a02347af987d8f73fa3108450e2b4a11c1ce5755")
            
            let metadata = try RuntimeMetadataContainer.createFromOpaque(data: rawMetadata.metadata)
            
            Logger.shared.info("Metadata opaque: \(metadata)")
        } catch {
            XCTFail("Error: \(error)")
        }
    }

    func performTestFetchLatestMetadata(for chainId: ChainModel.Id) throws -> RawRuntimeMetadata {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }
        
        let operationQueue = OperationQueue()
        
        let wrapper = RuntimeFetchOperationFactory(operationQueue: operationQueue).createMetadataFetchWrapper(
            for: chainId,
            connection: connection
        )
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
