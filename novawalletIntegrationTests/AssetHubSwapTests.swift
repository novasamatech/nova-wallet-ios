import XCTest
@testable import novawallet

final class AssetHubSwapTests: XCTestCase {
    func testWestmintAllDirections() throws {
        let directions = try performAvailableDirectionsFetch(
            for: KnowChainId.westmint,
            assetId: nil
        )
        
        Logger.shared.info("Directions: \(directions)")
    }
    
    func testWestmintNativeDirections() throws {
        let directions = try performAvailableDirectionsFetch(
            for: KnowChainId.westmint,
            assetId: 0
        )
        
        Logger.shared.info("Directions: \(directions)")
    }
    
    func testWestmintSiriDirections() throws {
        let directions = try performAvailableDirectionsFetch(
            for: KnowChainId.westmint,
            assetId: 1
        )
        
        Logger.shared.info("Directions: \(directions)")
    }
    
    private func performAvailableDirectionsFetch(
        for chainId: ChainModel.Id,
        assetId: AssetModel.Id?
    ) throws -> [ChainAssetId: Set<ChainAssetId>] {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }
        
        let operationQueue = OperationQueue()
        
        let operationFactory = AssetHubSwapOperationFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )
        
        if let assetId = assetId {
            let chainAssetId = ChainAssetId(chainId: chainId, assetId: assetId)
            let wrapper = operationFactory.availableDirectionsForAsset(chainAssetId)
            
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
            
            let directions = try wrapper.targetOperation.extractNoCancellableResultData()
            
            return [chainAssetId: directions]
        } else {
            let wrapper = operationFactory.availableDirections()
            
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
            
            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
    }
}
