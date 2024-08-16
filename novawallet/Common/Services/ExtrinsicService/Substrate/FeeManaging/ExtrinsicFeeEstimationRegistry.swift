import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedChainAssetId(ChainAssetId)
}

final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainModel
    let flowState: HydraFlowState
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        flowState: HydraFlowState,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.flowState = flowState
        self.operationQueue = operationQueue
    }

    private func createNativeFeeEstimatingWrapper(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
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

    private func createAssetConversionFeeEstimationWrapper(
        chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        ExtrinsicAssetsCustomFeeEstimator(
            chainAsset: chainAsset,
            operationQueue: operationQueue
        ).createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }

    private func createHydraAssetFeeEstimationWrapper(
        chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        HydraExtrinsicAssetsCustomFeeEstimator(
            chainAsset: chainAsset,
            flowState: flowState,
            operationQueue: operationQueue
        ).createFeeEstimatingWrapper(
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }
}

extension ExtrinsicFeeEstimationRegistry: ExtrinsicFeeEstimationRegistring {
    func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetId?,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard let chainAssetId else {
            return createNativeFeeEstimatingWrapper(
                connection: connection,
                runtimeService: runtimeService,
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
            connection: connection,
            runtimeService: runtimeService,
            extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
        )
    }
    
    func createFeeEstimatingWrapper(
        for asset: AssetModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        switch AssetType(rawType: asset.type) {
        case .none, .orml where chain.hasHydrationTransferFees:
            createHydraAssetFeeEstimationWrapper(
                chainAsset: .init(chain: chain, asset: asset),
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .none, .orml:
            createNativeFeeEstimatingWrapper(
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .statemine where chain.hasAssetHubTransferFees:
            createAssetConversionFeeEstimationWrapper(
                chainAsset: .init(chain: chain, asset: asset),
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .statemine:
            createNativeFeeEstimatingWrapper(
                connection: connection,
                runtimeService: runtimeService,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .equilibrium, .evmNative, .evmAsset:
            .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }
    }

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetId?,
        connection _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
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
                chain: chain,
                asset: asset,
                chainAssetId: chainAssetId
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }
    }
    
    func createFeeInstallerWrapper(
        chain: ChainModel,
        asset: AssetModel,
        chainAssetId: ChainAssetId
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        switch AssetType(rawType: asset.type) {
        case .none:
            CompoundOperationWrapper.createWithResult(ExtrinsicNativeFeeInstaller())
        case .statemine:
            CompoundOperationWrapper.createWithResult(
                ExtrinsicAssetConversionFeeInstaller(
                    feeAsset: ChainAsset(chain: chain, asset: asset)
                )
            )
        case .orml where chain.hasHydrationTransferFees:
            CompoundOperationWrapper.createWithResult(
                HydraExtrinsicFeeInstaller(
                    feeAsset: ChainAsset(chain: chain, asset: asset)
                )
            )
        case .orml, .equilibrium, .evmNative, .evmAsset:
            throw ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
        }
    }
}
