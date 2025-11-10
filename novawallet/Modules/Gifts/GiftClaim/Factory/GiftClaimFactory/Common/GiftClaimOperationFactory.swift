import Foundation
import BigInt
import Operation_iOS

typealias GiftClaimWrapperProvider = (
    _ giftWrapper: CompoundOperationWrapper<GiftModel>,
) -> CompoundOperationWrapper<Void>

protocol GiftClaimFactoryProtocol {
    func claimGift(
        using description: ClaimableGiftDescription,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void>
}

final class GiftClaimFactory {
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

private extension GiftClaimFactory {
    func createCleanGiftWrapper(
        for giftAccountId: @escaping () throws -> AccountId,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<Void> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
            let secretInfo = GiftSecretKeyInfo(
                accountId: try giftAccountId(),
                ethereumBased: chainAsset.chain.isEthereumBased
            )

            return CompoundOperationWrapper(
                targetOperation: self.giftSecretsCleaningFactory.cleanSecrets(for: secretInfo)
            )
        }
    }
}

// MARK: - GiftClaimFactoryProtocol

extension GiftClaimFactory: GiftClaimFactoryProtocol {
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
            giftWrapper
        )
        let cleaningWrapper = createCleanGiftWrapper(
            for: { try giftWrapper.targetOperation.extractNoCancellableResultData().giftAccountId },
            chainAsset: description.chainAsset
        )

        claimWrapper.addDependency(wrapper: giftWrapper)
        cleaningWrapper.addDependency(wrapper: claimWrapper)

        return cleaningWrapper
            .insertingHead(operations: claimWrapper.allOperations)
            .insertingHead(operations: giftWrapper.allOperations)
    }
}
