import Foundation
import Operation_iOS
import SubstrateSdk

final class AssetConversionFeeEstimatingFactory {
    let host: ExtrinsicFeeEstimatorHostProtocol

    private var hydraFlowState: HydraFlowState?

    init(host: ExtrinsicFeeEstimatorHostProtocol) {
        self.host = host
    }

    private func setupHydraFlowState() -> HydraFlowState {
        if let hydraFlowState {
            return hydraFlowState
        }

        let hydraFlowState = AssetConversionFeeSharedStateStore.getOrCreateHydra(for: host)
        self.hydraFlowState = hydraFlowState

        return hydraFlowState
    }
}

extension AssetConversionFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        switch AssetType(rawType: chainAsset.asset.type) {
        case .orml where chainAsset.chain.hasHydrationFees:
            let hydraState = setupHydraFlowState()
            let hydraQuoteFactory = HydraQuoteFactory(flowState: hydraState)
            let tokensFactory = HydraTokensFactory.createWithDefaultPools(
                chain: chainAsset.chain,
                runtimeService: host.runtimeProvider,
                connection: host.connection,
                operationQueue: host.operationQueue
            )

            let quoteFactory = HydraFeeQuoteFactory(
                realQuoteFactory: hydraQuoteFactory,
                tokensFactory: tokensFactory,
                operationQueue: host.operationQueue
            )

            return ExtrinsicAssetConversionFeeEstimator(
                chainAsset: chainAsset,
                operationQueue: host.operationQueue,
                quoteFactory: quoteFactory
            )
        case .statemine where chainAsset.chain.hasAssetHubFees:
            let assetHubQuoteFactory = AssetHubSwapOperationFactory(
                chain: host.chain,
                runtimeService: host.runtimeProvider,
                connection: host.connection,
                operationQueue: host.operationQueue
            )

            return ExtrinsicAssetConversionFeeEstimator(
                chainAsset: chainAsset,
                operationQueue: host.operationQueue,
                quoteFactory: assetHubQuoteFactory
            )
        case .none, .equilibrium, .evmNative, .evmAsset, .orml, .statemine:
            return nil
        }
    }
}
