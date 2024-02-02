import XCTest
@testable import novawallet
import BigInt
import RobinHood

final class HydraDxSwapTests: XCTestCase {
    func testAllAvailableDirections() {
        do {
            let directions = try performAvailableDirectionsFetch(
                for: KnowChainId.hydra,
                assetId: nil
            )
            
            Logger.shared.info("Directions: \(directions)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testHydraAssetDirections() {
        do {
            let directions = try performAvailableDirectionsFetch(
                for: KnowChainId.hydra,
                assetId: 0
            )
            
            Logger.shared.info("Directions: \(directions)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testQuotePolkadotHydraSell() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: .init(chainId: KnowChainId.hydra, assetId: 1),
                    assetOut: .init(chainId: KnowChainId.hydra, assetId: 0),
                    amount: 10_000_000_000,
                    direction: .sell
                )
            )
            
            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testQuotePolkadotHydraBuy() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: .init(chainId: KnowChainId.hydra, assetId: 1),
                    assetOut: .init(chainId: KnowChainId.hydra, assetId: 0),
                    amount: 1_000_000_000_000,
                    direction: .buy
                )
            )
            
            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testCanPayFeeInDot() {
        do {
            let canPayFee = try performCanPayFee(
                in: .init(chainId: KnowChainId.hydra, assetId: 1)
            )
            
            Logger.shared.info("Can pay fee: \(canPayFee)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
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
        
        let operationFactory = HydraOmnipoolOperationFactory(
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
    
    private func performQuoteFetch(for args: AssetConversion.QuoteArgs) throws -> AssetConversion.Quote {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = args.assetIn.chainId
        
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }
        
        let operationQueue = OperationQueue()
        
        let operationFactory = HydraOmnipoolOperationFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )
        
        let quoteWrapper = operationFactory.quote(for: args)
        
        operationQueue.addOperations(quoteWrapper.allOperations, waitUntilFinished: true)
        
        return try quoteWrapper.targetOperation.extractNoCancellableResultData()
    }
    
    private func performCanPayFee(in chainAssetId: ChainAssetId) throws -> Bool {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        let chainId = chainAssetId.chainId
        
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw ChainRegistryError.noChain(chainId)
        }
        
        let operationQueue = OperationQueue()
        
        let operationFactory = HydraOmnipoolOperationFactory(
            chain: chain,
            runtimeService: runtimeService,
            connection: connection,
            operationQueue: operationQueue
        )
        
        let wrapper = operationFactory.canPayFee(in: chainAssetId)
        
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)
        
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
