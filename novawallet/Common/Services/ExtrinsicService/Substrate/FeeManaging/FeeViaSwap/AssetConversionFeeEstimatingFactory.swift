import Foundation
import Operation_iOS
import SubstrateSdk

final class AssetConversionFeeEstimatingFactory {
    let host: ExtrinsicFeeEstimatorHostProtocol
    let feeBufferInPercentage: BigRational

    private var hydraFlowState: HydraFlowState?

    init(
        host: ExtrinsicFeeEstimatorHostProtocol,
        feeBufferInPercentage: BigRational = BigRational.percent(of: 0) // no overestimation by default
    ) {
        self.host = host
        self.feeBufferInPercentage = feeBufferInPercentage
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

            let quoteFactory = HydraFeeQuoteFactory(
                chain: chainAsset.chain,
                realQuoteFactory: hydraQuoteFactory,
                connection: host.connection,
                runtimeService: host.runtimeProvider,
                operationQueue: host.operationQueue
            )

            return ExtrinsicAssetConversionFeeEstimator(
                chainAsset: chainAsset,
                operationQueue: host.operationQueue,
                quoteFactory: quoteFactory,
                feeBufferInPercentage: feeBufferInPercentage
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
                quoteFactory: assetHubQuoteFactory,
                feeBufferInPercentage: feeBufferInPercentage
            )
        case .none, .equilibrium, .evmNative, .evmAsset, .orml, .statemine:
            return nil
        }
    }
}
