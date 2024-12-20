import Operation_iOS
import SubstrateSdk

protocol ExtrinsicFeeEstimatingWrapperFactoryProtocol {
    func createNativeFeeEstimatingWrapper(
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>

    func createCustomFeeEstimatingWrapper(
        asset: AssetModel,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>
}

final class ExtrinsicFeeEstimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol {
    let host: ExtrinsicFeeEstimatorHostProtocol
    let customFeeEstimatorFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol

    init(
        host: ExtrinsicFeeEstimatorHostProtocol,
        customFeeEstimatorFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol
    ) {
        self.host = host
        self.customFeeEstimatorFactory = customFeeEstimatorFactory
    }

    func createNativeFeeEstimatingWrapper(
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        ExtrinsicNativeFeeEstimator(
            chain: host.chain,
            operationQueue: host.operationQueue
        ).createFeeEstimatingWrapper(
            connection: host.connection,
            runtimeService: host.runtimeProvider,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    func createCustomFeeEstimatingWrapper(
        asset: AssetModel,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        let chainAsset = ChainAsset(chain: host.chain, asset: asset)

        guard
            let customFeeEstimator = customFeeEstimatorFactory.createCustomFeeEstimator(
                for: chainAsset
            ) else {
            return .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAsset.chainAssetId)
            )
        }

        return customFeeEstimator.createFeeEstimatingWrapper(
            connection: host.connection,
            runtimeService: host.runtimeProvider,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }
}
