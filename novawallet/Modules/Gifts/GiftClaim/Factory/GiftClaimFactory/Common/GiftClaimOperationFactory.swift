import Foundation
import BigInt
import Operation_iOS

typealias GiftClaimWrapperProvider = (
    _ giftWrapper: CompoundOperationWrapper<GiftModel>,
    _ amount: OnChainTransferAmount<BigUInt>
) -> CompoundOperationWrapper<Void>

protocol GiftClaimOperationFactoryProtocol {
    func claimGift(
        using description: ClaimableGiftDescription,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void>
}

final class GiftClaimOperationFactory {
    let giftFactory: GiftOperationFactoryProtocol
    let giftSecretsCleaningFactory: GiftSecretsCleaningProtocol
    let operationQueue: OperationQueue
    
    init(
        giftFactory: GiftOperationFactoryProtocol,
        giftSecretsCleaningFactory: GiftSecretsCleaningProtocol,
        operationQueue: OperationQueue
    ) {
        self.giftFactory = giftFactory
        self.giftSecretsCleaningFactory = giftSecretsCleaningFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftClaimOperationFactory {
    func createCleanGiftWrapper(
        dependingOn giftOperation: CompoundOperationWrapper<GiftModel>,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Void> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let gift = try giftOperation.targetOperation.extractNoCancellableResultData()
            
            let secretInfo = GiftSecretKeyInfo(
                accountId: gift.giftAccountId,
                ethereumBased: chainAsset.chain.isEthereumBased
            )
            
            return CompoundOperationWrapper(
                targetOperation: self.giftSecretsCleaningFactory.cleanSecrets(for: secretInfo)
            )
        }
    }
}

// MARK: - GiftClaimOperationFactoryProtocol

extension GiftClaimOperationFactory: GiftClaimOperationFactoryProtocol {
    func claimGift(
        using description: ClaimableGiftDescription,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void> {
        let giftWrapper = giftFactory.createGiftWrapper(
            from: description.seed,
            amount: description.amount.value,
            chainAsset: description.chainAsset
        )
        let claimWrapper = claimWrapperProvider(
            giftWrapper,
            description.amount
        )
        let cleaningWrapper = createCleanGiftWrapper(
            dependingOn: giftWrapper,
            chainAsset: description.chainAsset
        )
        
        claimWrapper.addDependency(wrapper: giftWrapper)
        cleaningWrapper.addDependency(wrapper: claimWrapper)
        
        return cleaningWrapper
            .insertingHead(operations: claimWrapper.allOperations)
            .insertingHead(operations: giftWrapper.allOperations)
    }
}
