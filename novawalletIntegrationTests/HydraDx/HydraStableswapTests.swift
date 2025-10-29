import XCTest
@testable import novawallet
import BigInt
import Operation_iOS

final class HydraStableswapTests: XCTestCase {
    func testCalculateSellWhenAssetInIsPoolAsset() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: 100,
                    assetOut: 10,
                    poolAsset: 100,
                    amount: 1_000_000_000_000_000_000,
                    direction: .sell
                )
            )

            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCalculateBuyWhenAssetInIsPoolAsset() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: 100,
                    assetOut: 10,
                    poolAsset: 100,
                    amount: 1_000_000,
                    direction: .buy
                )
            )

            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCalculateSellWhenAssetOutIsPoolAsset() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: 10,
                    assetOut: 100,
                    poolAsset: 100,
                    amount: 1_000_000,
                    direction: .sell
                )
            )

            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCalculateBuyWhenAssetOutIsPoolAsset() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: 10,
                    assetOut: 100,
                    poolAsset: 100,
                    amount: 1_000_000_000_000_000_000,
                    direction: .buy
                )
            )

            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCalculateSellForNonPoolAssets() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: 10,
                    assetOut: 18,
                    poolAsset: 100,
                    amount: 1_000_000,
                    direction: .sell
                )
            )

            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCalculateBuyForNonPoolAssets() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: 10,
                    assetOut: 18,
                    poolAsset: 100,
                    amount: 1_000_000_000_000_000_000,
                    direction: .buy
                )
            )

            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSellUSDTUSDC() {
        do {
            let quote = try performQuoteFetch(
                for: .init(
                    assetIn: 10,
                    assetOut: 22,
                    poolAsset: 102,
                    amount: 1_000_000,
                    direction: .sell
                )
            )

            Logger.shared.info("Quote: \(quote)")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performQuoteFetch(
        for args: HydraStableswap.QuoteArgs,
        chainId: ChainModel.Id = KnowChainId.hydra
    ) throws -> String {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let wallet = AccountGenerator.generateMetaAccount()

        guard
            let chain = chainRegistry.getChain(for: chainId),
            let connection = chainRegistry.getConnection(for: chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let account = wallet.fetch(for: chain.accountRequest()) else {
            throw ChainRegistryError.noChain(chainId)
        }

        let operationQueue = OperationQueue()

        let flowState = HydraStableswapFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            notificationsRegistrar: nil,
            operationQueue: operationQueue
        )

        let operationFactory = HydraStableswapQuoteFactory(flowState: flowState)

        let quoteWrapper = operationFactory.quote(for: args)

        operationQueue.addOperations(quoteWrapper.allOperations, waitUntilFinished: true)

        let amount = try quoteWrapper.targetOperation.extractNoCancellableResultData()

        return String(amount)
    }
}
