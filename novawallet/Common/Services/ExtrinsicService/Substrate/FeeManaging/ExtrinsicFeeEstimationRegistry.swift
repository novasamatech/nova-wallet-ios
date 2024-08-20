import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedChainAssetId(ChainAssetId)
}

final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainModel
    let estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol
    let chainRegistry: ChainRegistryProtocol
    let userStorageFacade: StorageFacadeProtocol
    let substrateStorageFacade: StorageFacadeProtocol

    /// We need to keep HydraFlowStates alive until the flow is complete,
    /// so we collect strong references received during HydraFlowStore updates.
    var existingFlowsStates: [HydraFlowState] = []

    private lazy var flowStateStore: HydraFlowStateStore = {
        let store = HydraFlowStateStore.getShared(
            for: chainRegistry,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade
        )

        store.subscribeForChangesUpdates(self)

        return store
    }()

    init(
        chain: ChainModel,
        estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol
    ) {
        self.chain = chain
        self.estimatingWrapperFactory = estimatingWrapperFactory
        self.chainRegistry = chainRegistry
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
    }
}

extension ExtrinsicFeeEstimationRegistry: HydraFlowStateStoreSubscriber {
    func flowStateStoreDidUpdate(_ newStates: [HydraFlowState]) {
        existingFlowsStates = newStates
    }
}

extension ExtrinsicFeeEstimationRegistry: ExtrinsicFeeEstimationRegistring {
    func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetId?,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard let chainAssetId else {
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        guard
            chain.chainId == chainAssetId.chainId,
            let asset = chain.asset(for: chainAssetId.assetId)
        else {
            return CompoundOperationWrapper.createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }

        return createFeeEstimatingWrapper(
            for: asset,
            chainAssetId: chainAssetId,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    func createFeeEstimatingWrapper(
        for asset: AssetModel,
        chainAssetId: ChainAssetId,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        switch AssetType(rawType: asset.type) {
        case .none:
            estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .orml where chain.hasHydrationTransferFees:
            estimatingWrapperFactory.createHydraFeeEstimatingWrapper(
                asset: asset,
                flowStateStore: flowStateStore,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .statemine where chain.hasAssetHubTransferFees:
            estimatingWrapperFactory.createCustomFeeEstimatingWrapper(
                asset: asset,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .equilibrium, .evmNative, .evmAsset, .orml, .statemine:
            .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }
    }

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetId?,
        senderResolutionOperation: ClosureOperation<ExtrinsicSenderBuilderResolution>
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        guard let chainAssetId else {
            return CompoundOperationWrapper.createWithResult(ExtrinsicNativeFeeInstaller())
        }

        do {
            guard
                chainAssetId.chainId == chain.chainId,
                let asset = chain.asset(for: chainAssetId.assetId)
            else {
                throw ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            }

            return createFeeInstallerWrapper(
                senderResolutionOperation: senderResolutionOperation,
                chainAsset: ChainAsset(chain: chain, asset: asset)
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }

    func createFeeInstallerWrapper(
        senderResolutionOperation: ClosureOperation<ExtrinsicSenderBuilderResolution>,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        switch AssetType(rawType: chainAsset.asset.type) {
        case .none:
            CompoundOperationWrapper.createWithResult(ExtrinsicNativeFeeInstaller())
        case .statemine where chain.hasAssetHubTransferFees:
            CompoundOperationWrapper.createWithResult(
                ExtrinsicAssetConversionFeeInstaller(
                    feeAsset: chainAsset
                )
            )
        case .orml where chain.hasHydrationTransferFees:
            createHydraFeeInstallingWrapper(
                senderResolutionOperation: senderResolutionOperation,
                chainAsset: chainAsset
            )
        case .orml, .statemine, .equilibrium, .evmNative, .evmAsset:
            .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAsset.chainAssetId)
            )
        }
    }

    private func createHydraFeeInstallingWrapper(
        senderResolutionOperation: ClosureOperation<ExtrinsicSenderBuilderResolution>,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        let swapStateWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: OperationQueue())
        ) { [weak self] in
            guard let self else {
                throw BaseOperationError.parentOperationCancelled
            }

            let account = try senderResolutionOperation.extractNoCancellableResultData().sender.account
            let swapStateFetchOperation = try flowStateStore.setupFlowState(
                account: account,
                chain: chainAsset.chain,
                queue: OperationQueue()
            )
            .setupSwapService()
            .createFetchOperation()

            return CompoundOperationWrapper(targetOperation: swapStateFetchOperation)
        }

        swapStateWrapper.addDependency(operations: [senderResolutionOperation])

        return createHydraFeeInstallingWrapper(
            using: swapStateWrapper,
            chainAsset: chainAsset
        )
    }

    private func createHydraFeeInstallingWrapper(
        using swapStateWrapper: CompoundOperationWrapper<HydraDx.SwapRemoteState>,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        let operation = ClosureOperation<ExtrinsicFeeInstalling> {
            let swapState = try swapStateWrapper.targetOperation.extractNoCancellableResultData()

            return HydraExtrinsicFeeInstaller(
                feeAsset: chainAsset,
                swapState: swapState
            )
        }

        operation.addDependency(swapStateWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: swapStateWrapper.allOperations
        )
    }
}
