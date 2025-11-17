import Foundation
import BigInt
import Operation_iOS

typealias GiftClaimWrapperProvider = (
    _ giftWrapper: CompoundOperationWrapper<GiftModel>
) -> CompoundOperationWrapper<Void>

protocol GiftClaimFactoryProtocol {
    func claimGift(
        using description: ClaimableGiftDescription,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void>
}

final class GiftClaimFactory {
    let giftFactory: GiftOperationFactoryProtocol
    let claimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol
    let operationQueue: OperationQueue

    init(
        giftFactory: GiftOperationFactoryProtocol,
        claimAvailabilityCheckFactory: GiftClaimAvailabilityCheckFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.giftFactory = giftFactory
        self.claimAvailabilityCheckFactory = claimAvailabilityCheckFactory
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension GiftClaimFactory {
    func createGiftWrapperOrError(
        basedOn claimAvailabilityWrapper: CompoundOperationWrapper<GiftClaimAvailabilityCheckResult>,
        seed: Data,
        amount: BigUInt,
        chainAsset: ChainAsset
    ) -> CompoundOperationWrapper<GiftModel> {
        OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let claimCheckResult = try claimAvailabilityWrapper.targetOperation.extractNoCancellableResultData()

            switch claimCheckResult.availability {
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
}

// MARK: - GiftClaimFactoryProtocol

extension GiftClaimFactory: GiftClaimFactoryProtocol {
    func claimGift(
        using description: ClaimableGiftDescription,
        claimWrapperProvider: GiftClaimWrapperProvider
    ) -> CompoundOperationWrapper<Void> {
        let claimAvailabilityWrapper = claimAvailabilityCheckFactory.createAvailabilityWrapper(
            for: description
        )
        let giftWrapper = createGiftWrapperOrError(
            basedOn: claimAvailabilityWrapper,
            seed: description.seed,
            amount: description.amount.value,
            chainAsset: description.chainAsset
        )
        let claimWrapper = claimWrapperProvider(
            giftWrapper
        )

        giftWrapper.addDependency(wrapper: claimAvailabilityWrapper)
        claimWrapper.addDependency(wrapper: giftWrapper)

        return claimWrapper
            .insertingHead(operations: giftWrapper.allOperations)
            .insertingHead(operations: claimAvailabilityWrapper.allOperations)
    }
}
