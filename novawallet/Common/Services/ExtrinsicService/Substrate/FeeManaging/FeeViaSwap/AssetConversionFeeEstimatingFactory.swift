import Foundation
import Operation_iOS
import SubstrateSdk

final class AssetConversionFeeEstimatingFactory {
    let host: ExtrinsicFeeEstimatorHostProtocol
    let feeBufferInPercentage: BigRational

    init(
        host: ExtrinsicFeeEstimatorHostProtocol,
        feeBufferInPercentage: BigRational = BigRational.percent(of: 0) // no overestimation by default
    ) {
        self.host = host
        self.feeBufferInPercentage = feeBufferInPercentage
    }
}

extension AssetConversionFeeEstimatingFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol {
    func createCustomFeeEstimator(for chainAsset: ChainAsset) -> ExtrinsicFeeEstimating? {
        switch AssetType(rawType: chainAsset.asset.type) {
        case .orml where chainAsset.chain.hasHydrationFees,
             .ormlHydrationEvm where chainAsset.chain.hasHydrationFees:
            let quoteFactory = HydraFeeQuoteFactory(
                priceFactory: HydraFeeOraclePriceFactory(
                    chain: chainAsset.chain,
                    connection: host.connection,
                    runtimeService: host.runtimeProvider,
                    operationQueue: host.operationQueue,
                    logger: host.logger
                )
            )

            return ExtrinsicAssetConversionFeeEstimator(
                chainAsset: chainAsset,
                operationQueue: host.operationQueue,
                quoteFactory: quoteFactory,
                feeBufferInPercentage: .percent(of: 0)
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
        case .none, .equilibrium, .evmNative, .evmAsset, .orml, .ormlHydrationEvm, .statemine:
            return nil
        }
    }
}
