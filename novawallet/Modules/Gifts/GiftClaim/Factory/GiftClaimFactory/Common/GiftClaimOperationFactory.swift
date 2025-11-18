import Foundation
import BigInt
import Operation_iOS

typealias GiftClaimWrapperProvider = (
    _ giftWrapper: CompoundOperationWrapper<GiftModel>,
    _ chainAsset: ChainAsset
) -> CompoundOperationWrapper<Void>

protocol GiftClaimFactoryProtocol {
    func claimGift(
        using description: ClaimableGiftDescription,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void>

    func reclaimGift(
        _ gift: GiftModel,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void>
}

final class GiftClaimFactory {
    let chainRegistry: ChainRegistryProtocol
    let giftFactory: GiftOperationFactoryProtocol
    let claimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol
    let operationQueue: OperationQueue

    init(
        chainRegistry: ChainRegistryProtocol,
        giftFactory: GiftOperationFactoryProtocol,
        claimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainRegistry = chainRegistry
        self.giftFactory = giftFactory
        self.claimAvailabilityCheckFactory = claimAvailabilityCheckFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftClaimFactory {
    func createGiftWrapperOrError(
        basedOn claimAvailabilityWrapper: CompoundOperationWrapper<GiftClaimAvailabilty>,
        seed: Data,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<GiftModel> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let claimCheckResult = try claimAvailabilityWrapper.targetOperation.extractNoCancellableResultData()

            switch claimCheckResult {
            case .claimable:
                return giftFactory.createGiftWrapper(
                    from: seed,
                    amount: amount,
                    chainAsset: chainAsset
                )
            case .claimed:
                throw GiftClaimError.alreadyClaimed
            }
        }
    }

    func reclaimableGiftWrapper(
        gift: GiftModel,
        basedOn claimAvailabilityWrapper: CompoundOperationWrapper<GiftClaimAvailabilty>
    ) -> CompoundOperationWrapper<GiftModel> {
        .init(targetOperation: ClosureOperation {
            let claimCheckResult = try claimAvailabilityWrapper.targetOperation.extractNoCancellableResultData()

            switch claimCheckResult {
            case .claimable:
                return gift
            case .claimed:
                throw GiftClaimError.alreadyClaimed
            }
        })
    }
}

// MARK: - GiftClaimFactoryProtocol

extension GiftClaimFactory: GiftClaimFactoryProtocol {
    func claimGift(
        using description: ClaimableGiftDescription,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void> {
        let claimAvailabilityWrapper = claimAvailabilityCheckFactory.createAvailabilityWrapper(
            for: description.accountId,
            chainAssetId: description.chainAsset.chainAssetId
        )
        let giftWrapper = createGiftWrapperOrError(
            basedOn: claimAvailabilityWrapper,
            seed: description.seed,
            amount: description.amount.value,
            chainAsset: description.chainAsset
        )
        let claimWrapper = claimWrapperProvider(
            giftWrapper,
            description.chainAsset
        )

        giftWrapper.addDependency(wrapper: claimAvailabilityWrapper)
        claimWrapper.addDependency(wrapper: giftWrapper)

        return claimWrapper
            .insertingHead(operations: giftWrapper.allOperations)
            .insertingHead(operations: claimAvailabilityWrapper.allOperations)
    }

    func reclaimGift(
        _ gift: GiftModel,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void> {
        do {
            let chain = try chainRegistry.getChainOrError(for: gift.chainAssetId.chainId)
            let chainAsset = try chain.chainAssetOrError(for: gift.chainAssetId.assetId)

            let claimAvailabilityWrapper = claimAvailabilityCheckFactory.createAvailabilityWrapper(
                for: gift.giftAccountId,
                chainAssetId: gift.chainAssetId
            )

            let giftWrapper = reclaimableGiftWrapper(gift: gift, basedOn: claimAvailabilityWrapper)

            let claimWrapper = claimWrapperProvider(
                giftWrapper,
                chainAsset
            )

            giftWrapper.addDependency(wrapper: claimAvailabilityWrapper)
            claimWrapper.addDependency(wrapper: giftWrapper)

            return claimWrapper
                .insertingHead(operations: giftWrapper.allOperations)
                .insertingHead(operations: claimAvailabilityWrapper.allOperations)
        } catch {
            return .createWithError(error)
        }
    }
}
