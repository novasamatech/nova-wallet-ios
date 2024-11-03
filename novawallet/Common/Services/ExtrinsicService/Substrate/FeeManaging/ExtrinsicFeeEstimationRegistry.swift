import Foundation
import Operation_iOS
import SubstrateSdk

enum ExtrinsicFeeEstimationRegistryError: Error {
    case unexpectedChainAssetId(ChainAssetId)
}

final class ExtrinsicFeeEstimationRegistry {
    let chain: ChainModel
    let estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol
    let feeInstallingWrapperFactory: ExtrinsicFeeInstallingWrapperFactoryProtocol

    init(
        chain: ChainModel,
        estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactoryProtocol,
        feeInstallingWrapperFactory: ExtrinsicFeeInstallingWrapperFactoryProtocol
    ) {
        self.chain = chain
        self.estimatingWrapperFactory = estimatingWrapperFactory
        self.feeInstallingWrapperFactory = feeInstallingWrapperFactory
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
        chainAssetId _: ChainAssetId,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol> {
        guard !asset.isUtility else {
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }

        switch AssetType(rawType: asset.type) {
        case .none:
            return estimatingWrapperFactory.createNativeFeeEstimatingWrapper(
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        case .equilibrium, .evmNative, .evmAsset, .orml, .statemine:
            return estimatingWrapperFactory.createCustomFeeEstimatingWrapper(
                asset: asset,
                extrinsicCreatingResultClosure: extrinsicCreatingResultClosure
            )
        }
    }

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetId?,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        guard let chainAssetId else {
            return feeInstallingWrapperFactory.createNativeFeeInstallerWrapper(accountClosure: accountClosure)
        }

        guard
            chainAssetId.chainId == chain.chainId,
            let asset = chain.chainAsset(for: chainAssetId.assetId)
        else {
            return .createWithError(
                ExtrinsicFeeEstimationRegistryError.unexpectedChainAssetId(chainAssetId)
            )
        }

        return createFeeInstallerWrapper(chainAsset: asset, accountClosure: accountClosure)
    }

    func createFeeInstallerWrapper(
        chainAsset: ChainAsset,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling> {
        guard !chainAsset.isUtilityAsset else {
            return feeInstallingWrapperFactory.createNativeFeeInstallerWrapper(accountClosure: accountClosure)
        }

        switch AssetType(rawType: chainAsset.asset.type) {
        case .none:
            return feeInstallingWrapperFactory.createNativeFeeInstallerWrapper(
                accountClosure: accountClosure
            )
        case .equilibrium, .evmNative, .evmAsset, .orml, .statemine:
            return feeInstallingWrapperFactory.createCustomFeeInstallerWrapper(
                chainAsset: chainAsset,
                accountClosure: accountClosure
            )
        }
    }
}
