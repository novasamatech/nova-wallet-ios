import Foundation
import Operation_iOS

final class SubstrateGiftReclaimWrapperFactory: GiftReclaimStatusUpdating {
    let chainRegistry: ChainRegistryProtocol
    let giftRepository: AnyDataProviderRepository<GiftModel>
    let walletChecker: GiftReclaimWalletCheckerProtocol
    let claimOperationFactory: SubstrateGiftClaimFactoryProtocol
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        giftRepository: AnyDataProviderRepository<GiftModel>,
        walletChecker: GiftReclaimWalletCheckerProtocol,
        claimOperationFactory: SubstrateGiftClaimFactoryProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.giftRepository = giftRepository
        self.walletChecker = walletChecker
        self.claimOperationFactory = claimOperationFactory
        self.assetStorageInfoFactory = assetStorageInfoFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - GiftReclaimWrapperFactoryProtocol

extension SubstrateGiftReclaimWrapperFactory: GiftReclaimWrapperFactoryProtocol {
    func reclaimGift(
        _ gift: GiftModel,
        selectedWallet: MetaAccountModel
    ) -> CompoundOperationWrapper<Void> {
        do {
            let chain = try chainRegistry.getChainOrError(for: gift.chainAssetId.chainId)
            let chainAsset = try chain.chainAssetOrError(for: gift.chainAssetId.assetId)
            let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chain.chainId)

            let recipientAccountId = try walletChecker.findGiftRecipientAccount(
                for: chain,
                in: selectedWallet
            )

            let storageInfoWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
                from: chainAsset.asset,
                runtimeProvider: runtimeProvider
            )

            let reclaimWrapper = OperationCombiningService.compoundNonOptionalWrapper(
                operationQueue: operationQueue
            ) {
                let storageInfo = try storageInfoWrapper.targetOperation.extractNoCancellableResultData()

                return self.claimOperationFactory.createReclaimWrapper(
                    gift: gift,
                    claimingAccountId: recipientAccountId,
                    assetStorageInfo: storageInfo
                )
            }

            let statusUpdateOperation = createPersistedStatusUpdateOperation(
                for: gift,
                dependingOn: reclaimWrapper
            )

            reclaimWrapper.addDependency(wrapper: storageInfoWrapper)
            statusUpdateOperation.addDependency(reclaimWrapper.targetOperation)

            return reclaimWrapper
                .insertingHead(operations: storageInfoWrapper.allOperations)
                .insertingTail(operation: statusUpdateOperation)
        } catch {
            return .createWithError(error)
        }
    }
}
