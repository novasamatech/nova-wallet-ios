import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedChainAssetId(ChainAssetId)
}

final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainModel
    let estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.estimatingWrapperFactory = estimatingWrapperFactory
        self.operationQueue = operationQueue
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
        case .none where chain.hasHydrationTransferFees,
             .orml where chain.hasHydrationTransferFees:
            estimatingWrapperFactory.createHydraFeeEstimatingWrapper(
                asset: asset,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .none, .orml:
            estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .statemine where chain.hasAssetHubTransferFees:
            estimatingWrapperFactory.createCustomFeeEstimatingWrapper(
                asset: asset,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .statemine:
            estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
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
        case .statemine where chain.hasAssetHubTransferFees:
            CompoundOperationWrapper.createWithResult(
                ExtrinsicAssetConversionFeeInstaller(
                    feeAsset: ChainAsset(chain: chain, asset: asset)
                )
            )
        case .none, .statemine:
            CompoundOperationWrapper.createWithResult(ExtrinsicNativeFeeInstaller())
        case .orml where chain.hasHydrationTransferFees:
            CompoundOperationWrapper.createWithResult(
                HydraExtrinsicFeeInstaller(
                    feeAsset: ChainAsset(chain: chain, asset: asset)
                )
            )
        case .orml, .equilibrium, .evmNative, .evmAsset:
            .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }
    }
}
