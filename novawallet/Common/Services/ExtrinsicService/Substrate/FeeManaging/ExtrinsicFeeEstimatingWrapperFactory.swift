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
    let nativeFeeEstimator: ExtrinsicFeeEstimating

    /**
     *  - Parameter nativeFeeEstimator: nil stands for `ExtrinsicNativeFeeEstimator`, which suits
     *    every caller that builds its own extrinsics.
     */
    init(
        host: ExtrinsicFeeEstimatorHostProtocol,
        customFeeEstimatorFactory: ExtrinsicCustomFeeEstimatingFactoryProtocol,
        nativeFeeEstimator: ExtrinsicFeeEstimating? = nil
    ) {
        self.host = host
        self.customFeeEstimatorFactory = customFeeEstimatorFactory

        self.nativeFeeEstimator = nativeFeeEstimator ?? ExtrinsicNativeFeeEstimator(
            chain: host.chain,
            operationQueue: host.operationQueue
        )
    }

    func createNativeFeeEstimatingWrapper(
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        nativeFeeEstimator.createFeeEstimatingWrapper(
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
