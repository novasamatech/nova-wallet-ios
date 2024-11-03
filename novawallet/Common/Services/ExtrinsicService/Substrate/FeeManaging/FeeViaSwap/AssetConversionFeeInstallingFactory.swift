import Foundation
import Operation_iOS

final class AssetConversionFeeInstallingFactory {
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

    private func createHydraFeeInstallingWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        let swapStateWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: host.operationQueue
        ) {
            let account = try accountClosure()

            let state = self.setupHydraFlowState()

            let swapStateFetchOperation = state.setupSwapService().createFetchOperation()

            return CompoundOperationWrapper(targetOperation: swapStateFetchOperation)
        }

        let mappingOperation = ClosureOperation<ExtrinsicFeeInstalling> {
            let swapState = try swapStateWrapper.targetOperation.extractNoCancellableResultData()

            return HydraExtrinsicFeeInstaller(feeAsset: chainAsset, swapState: swapState)
        }

        mappingOperation.addDependency(swapStateWrapper.targetOperation)

        return swapStateWrapper.insertingTail(operation: mappingOperation)
    }
}

extension AssetConversionFeeInstallingFactory: ExtrinsicCustomFeeInstallingFactoryProtocol {
    func createCustomFeeInstallerWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        switch AssetType(rawType: chainAsset.asset.type) {
        case .statemine where chainAsset.chain.hasAssetHubTransferFees:
            CompoundOperationWrapper.createWithResult(
                ExtrinsicAssetConversionFeeInstaller(
                    feeAsset: chainAsset
                )
            )
        case .orml where chainAsset.chain.hasHydrationTransferFees:
            createHydraFeeInstallingWrapper(
                chainAsset: chainAsset,
                accountClosure: accountClosure
            )
        case .none, .orml, .statemine, .equilibrium, .evmNative, .evmAsset:
            .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAsset.chainAssetId)
            )
        }
    }
}
