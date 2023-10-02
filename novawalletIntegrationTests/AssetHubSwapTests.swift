import XCTest
@testable import novawallet
import BigInt

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
    
    func testQuoteForWestmintSiriSell() throws {
        let quote = try fetchQuote(
            for: KnowChainId.westmint,
            assetIn: 0,
            assetOut: 1,
            direction: .sell
        )
        
        Logger.shared.info("Quote: \(quote)")
    }
    
    func testQuoteForWestmintSiriBuy() throws {
        let quote = try fetchQuote(
            for: KnowChainId.westmint,
            assetIn: 0,
            assetOut: 1,
            direction: .buy,
            amount: 1_000_000
        )
        
        Logger.shared.info("Quote: \(quote)")
    }
    
    func testQuoteForSiriWestmintSell() throws {
        let quote = try fetchQuote(
            for: KnowChainId.westmint,
            assetIn: 1,
            assetOut: 0,
            direction: .sell
        )
        
        Logger.shared.info("Quote: \(quote)")
    }
    
    func testQuoteForSiriWestmintBuy() throws {
        let quote = try fetchQuote(
            for: KnowChainId.westmint,
            assetIn: 1,
            assetOut: 0,
            direction: .buy,
            amount: 1_000_000
        )
        
        Logger.shared.info("Quote: \(quote)")
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
    
    private func fetchQuote(
        for chainId: ChainModel.Id,
        assetIn: AssetModel.Id,
        assetOut: AssetModel.Id,
        direction: AssetConversion.Direction,
        amount: BigUInt = 1_000_000_000_000
    ) throws -> AssetConversion.Quote {
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
        
        let args = AssetConversion.Args(
            assetIn: .init(chainId: chainId, assetId: assetIn),
            assetOut: .init(chainId: chainId, assetId: assetOut),
            amount: amount,
            direction: direction,
            slippage: 0
        )
        
        let quoteWrapper = operationFactory.quote(for: args)
        
        operationQueue.addOperations(quoteWrapper.allOperations, waitUntilFinished: true)
        
        return try quoteWrapper.targetOperation.extractNoCancellableResultData()
    }
}
