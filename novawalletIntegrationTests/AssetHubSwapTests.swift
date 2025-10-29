import XCTest
@testable import novawallet
import BigInt
import Operation_iOS

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

    func testFeeForWestmintSiriSellInNativeToken() throws {
        let amountIn: BigUInt = 1_000_000_000

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

        let fee = try fetchFee(for: callArgs, feeAssetId: .init(chainId: KnowChainId.westmint, assetId: 0))

        Logger.shared.info("Max fee: \(String(fee.amount))")
    }

    func testFeeForWestmintSiriSellInSiriToken() throws {
        let amountIn: BigUInt = 1_000_000_000

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

        let fee = try fetchFee(for: callArgs, feeAssetId: .init(chainId: KnowChainId.westmint, assetId: 1))

        Logger.shared.info("Max fee: \(String(fee.amount))")
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

    private func fetchFee(for args: AssetConversion.CallArgs, feeAssetId: ChainAssetId) throws -> ExtrinsicFeeProtocol {
        let substrateStorageFacade = SubstrateStorageTestFacade()
        let userStorageFacade = UserDataStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: substrateStorageFacade)

        let chainId = args.assetIn.chainId

        let wallet = AccountGenerator.generateMetaAccount(generatingChainAccounts: 1)

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let asset = chain.asset(for: feeAssetId.assetId),
            let chainAccount = wallet.fetch(for: chain.accountRequest()),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            throw CommonError.dataCorruption
        }

        let feeAsset = ChainAsset(chain: chain, asset: asset)

        let operationQueue = OperationQueue()

        let extrinsicOperationFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade
        ).createOperationFactory(account: chainAccount, chain: chain)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let feeWrapper = extrinsicOperationFactory.estimateFeeOperation({ builder in
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            return try AssetHubExtrinsicConverter.addingOperation(
                to: builder,
                chain: chain,
                args: args,
                codingFactory: codingFactory
            )
        }, payingIn: feeAsset.chainAssetId)

        feeWrapper.addDependency(operations: [codingFactoryOperation])

        let totalWrapper = feeWrapper.insertingHead(operations: [codingFactoryOperation])

        operationQueue.addOperations(totalWrapper.allOperations, waitUntilFinished: true)

        return try feeWrapper.targetOperation.extractNoCancellableResultData()
    }
}
