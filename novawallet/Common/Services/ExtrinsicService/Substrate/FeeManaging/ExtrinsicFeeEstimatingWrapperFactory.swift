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

    func createHydraFeeEstimatingWrapper(
        asset: AssetModel,
        flowStateStore: HydraFlowStateStore,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>
}

final class ExtrinsicFeeEstimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol {
    let account: ChainAccountResponse
    let chain: ChainModel
    let runtimeService: RuntimeProviderProtocol
    let connection: JSONRPCEngine
    let operationQueue: OperationQueue

    init(
        account: ChainAccountResponse,
        chain: ChainModel,
        runtimeService: RuntimeProviderProtocol,
        connection: JSONRPCEngine,
        operationQueue: OperationQueue
    ) {
        self.account = account
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationQueue = operationQueue
    }

    func createNativeFeeEstimatingWrapper(
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        ExtrinsicNativeFeeEstimator(
            chain: chain,
            operationQueue: operationQueue
        ).createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    func createCustomFeeEstimatingWrapper(
        asset: AssetModel,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        ExtrinsicAssetsCustomFeeEstimator(
            chainAsset: .init(chain: chain, asset: asset),
            operationQueue: operationQueue
        ).createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    func createHydraFeeEstimatingWrapper(
        asset: AssetModel,
        flowStateStore: HydraFlowStateStore,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        do {
            let flowState = try flowStateStore.setupFlowState(
                account: account,
                chain: chain,
                queue: operationQueue
            )

            return HydraExtrinsicAssetsCustomFeeEstimator(
                chainAsset: chainAsset,
                flowState: flowState,
                operationQueue: operationQueue
            ).createFeeEstimatingWrapper(
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
}
