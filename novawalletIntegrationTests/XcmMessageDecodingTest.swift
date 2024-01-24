import XCTest
@testable import novawallet
import SubstrateSdk

final class XcmMessageDecodingTest: XCTestCase {
    func testKusamaXcmMessageDecoding() {
        do {
            let chainId = KnowChainId.kusama
            let data = try Data(hexString: "031402040001000007b66d09a9040a130001000007b66d09a904000d0102040001010080b82857812caa107b9fced4e7f9369e994ac994483894cf1aa954fb995010562c7a40d695cf40eaba47760554c50006bd6bead11a0d18ed730d762b69d5c75d33")
            
            let message = try decodeXcmMessage(data, chainId: chainId)
            
            Logger.shared.info("Message: \(message)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
    }
    
    private func decodeXcmMessage(_ message: Data, chainId: ChainModel.Id) throws -> JSON {
        let facade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: facade)
        
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }
        
        let messageType = "449"
        
        let operation = runtimeProvider.fetchCoderFactoryOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        
        let codingFactory = try operation.extractNoCancellableResultData()
        
        let decoder = try codingFactory.createDecoder(from: message)
        
        return try decoder.read(type: messageType)
    }
}
