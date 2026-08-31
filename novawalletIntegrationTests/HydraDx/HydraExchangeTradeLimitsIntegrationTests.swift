import XCTest
@testable import novawallet
import Operation_iOS

final class HydraExchangeTradeLimitsIntegrationTests: XCTestCase {
    func testXYKRatiosDecodeFromLiveMetadata() {
        do {
            let ratios = try performRatiosFetch(for: .xyk)

            Logger.shared.info("XYK ratios: \(ratios)")

            XCTAssertTrue(ratios.maxInRatio > 0)
            XCTAssertTrue(ratios.maxOutRatio > 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOmnipoolRatiosDecodeFromLiveMetadata() {
        do {
            let ratios = try performRatiosFetch(for: .omnipool)

            Logger.shared.info("Omnipool ratios: \(ratios)")

            XCTAssertTrue(ratios.maxInRatio > 0)
            XCTAssertTrue(ratios.maxOutRatio > 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testINTRSellAboveTheXYKCapIsABreach() {
        do {
            let verdict = try performXYKTradeLimitVerdictFetch(
                assetIn: 17,
                assetOut: 0,
                amount: 463_695_496_566_549,
                direction: .sell
            )

            Logger.shared.info("Verdict: \(verdict)")

            guard case let .exceeds(breach) = verdict else {
                return XCTFail("Expected a breach")
            }

            let cap = try XCTUnwrap(breach.maxGivenAmount)

            XCTAssertLessThan(cap, 463_695_496_566_549)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performRatiosFetch(
        for constants: HydraExchangeTradeLimits.PalletLimitConstants
    ) throws -> HydraExchangeTradeLimits.PoolLimits {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: KnowChainId.hydra) else {
            throw ChainRegistryError.noChain(KnowChainId.hydra)
        }

        let operationQueue = OperationQueue()

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper = HydraExchangeTradeLimits.createPoolLimitsWrapper(
            for: constants,
            dependingOn: coderFactoryOperation
        ).insertingHead(operations: [coderFactoryOperation])

        return try withExtendedLifetime(chainRegistry) {
            operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: true)

            return try wrapper.targetOperation.extractNoCancellableResultData()
        }
    }

    private func performXYKTradeLimitVerdictFetch(
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        amount: Balance,
        direction: AssetConversion.Direction
    ) throws -> AssetExchangeTradeLimitVerdict {
        let storageFacade = SubstrateStorageTestFacade()
        let chainRegistry = ChainRegistryFacade.setupForIntegrationTest(with: storageFacade)

        let wallet = AccountGenerator.generateMetaAccount()

        guard
            let chain = chainRegistry.getChain(for: KnowChainId.hydra),
            let connection = chainRegistry.getConnection(for: KnowChainId.hydra),
            let runtimeService = chainRegistry.getRuntimeProvider(for: KnowChainId.hydra),
            let account = wallet.fetch(for: chain.accountRequest()) else {
            throw ChainRegistryError.noChain(KnowChainId.hydra)
        }

        let operationQueue = OperationQueue()

        let flowState = HydraXYKFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeService,
            notificationsRegistrar: nil,
            operationQueue: operationQueue,
            logger: Logger.shared
        )

        let quoteFactory = HydraXYKSwapQuoteFactory(flowState: flowState)

        let remoteSwapPair = HydraDx.RemoteSwapPair(assetIn: assetIn, assetOut: assetOut)
        let quoteStateWrapper = quoteFactory.quoteStateWrapper(for: remoteSwapPair)

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let limitsWrapper = HydraExchangeTradeLimits.createPoolLimitsWrapper(
            for: .xyk,
            dependingOn: coderFactoryOperation
        ).insertingHead(operations: [coderFactoryOperation])

        return try withExtendedLifetime(chainRegistry) {
            operationQueue.addOperations(
                quoteStateWrapper.allOperations + limitsWrapper.allOperations,
                waitUntilFinished: true
            )

            let remoteState = try quoteStateWrapper.targetOperation.extractNoCancellableResultData()
            let limits = try limitsWrapper.targetOperation.extractNoCancellableResultData()

            return try HydraXYKSwapQuoteFactory.tradeLimitVerdict(
                for: amount,
                direction: direction,
                remoteState: remoteState,
                limits: limits
            )
        }
    }
}
