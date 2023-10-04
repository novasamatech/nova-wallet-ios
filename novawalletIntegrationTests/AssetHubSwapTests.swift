import XCTest
@testable import novawallet
import BigInt
import RobinHood

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
    
    func testFeeForWestmintSiriSell() throws {
        let amountIn: BigUInt = 1_000_000_000_000
        
        let quote = try fetchQuote(
            for: KnowChainId.westmint,
            assetIn: 1,
            assetOut: 0,
            direction: .sell,
            amount: amountIn
        )
        
        let callArgs = AssetConversion.CallArgs(
            assetIn: quote.assetIn,
            amountIn: quote.amountIn,
            assetOut: quote.assetOut,
            amountOut: quote.amountOut,
            receiver: AccountId.zeroAccountId(of: 32),
            direction: .sell,
            slippage: .percent(of: 1)
        )
        
        let fee = try fetchNetworkFee(for: callArgs)
        
        Logger.shared.info("Fee: \(String(fee))")
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
        
        let args = AssetConversion.QuoteArgs(
            assetIn: .init(chainId: chainId, assetId: assetIn),
            assetOut: .init(chainId: chainId, assetId: assetOut),
            amount: amount,
            direction: direction
        )
        
        let quoteWrapper = operationFactory.quote(for: args)
        
        operationQueue.addOperations(quoteWrapper.allOperations, waitUntilFinished: true)
        
        return try quoteWrapper.targetOperation.extractNoCancellableResultData()
    }
    
    private func fetchNetworkFee(for args: AssetConversion.CallArgs) throws -> BigUInt {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)
        
        let chainId = args.assetIn.chainId
        
        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)
        
        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let accountResponse = wallet.fetch(for: chain.accountRequest()) else {
            throw ChainRegistryError.noChain(chainId)
        }
        
        let operationQueue = OperationQueue()
        
        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        ).createService(account: accountResponse, chain: chain)
        
        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()
        
        operationQueue.addOperations([codingFactoryOperation], waitUntilFinished: true)
        
        let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
        
        let builderClosure = AssetHubExtrinsicService(chain: chain).fetchExtrinsicBuilderClosure(
            for: args,
            codingFactory: codingFactory
        )
        
        var feeResult: FeeExtrinsicResult?
        
        let expectation = XCTestExpectation()
        
        extrinsicService.estimateFee(builderClosure, runningIn: .main) { result in
            feeResult = result
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 600)
        
        switch feeResult {
        case let .success(dispatchInfo):
            return BigUInt(dispatchInfo.fee) ?? 0
        case let .failure(error):
            throw error
        case .none:
            throw CommonError.undefined
        }
    }
}
