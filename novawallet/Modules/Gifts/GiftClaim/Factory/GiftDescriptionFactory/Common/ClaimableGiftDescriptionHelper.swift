import Foundation
import BigInt

struct ClaimableGiftBaseData {
    let onChainAmountWithFee: OnChainTransferAmount<BigUInt>
    let claimingAccountId: AccountId?
}

final class ClaimableGiftDescriptionHelper {
    func createBaseData(
        for claimableGift: ClaimableGift,
        giftAmountWithFee: BigUInt,
        claimingWallet: @escaping () throws -> MetaAccountModel
    ) throws -> ClaimableGiftBaseData {
        let chainAsset = claimableGift.chainAsset
        let onChainAmountWithFee: OnChainTransferAmount<BigUInt> = .all(value: giftAmountWithFee)

        let claimingAccountId = try claimingWallet().fetch(
            for: chainAsset.chain.accountRequest()
        )?.accountId

        return ClaimableGiftBaseData(
            onChainAmountWithFee: onChainAmountWithFee,
            claimingAccountId: claimingAccountId
        )
    }

    func createFinalDescription(
        claimableGift: ClaimableGift,
        onChainAmountWithFee: OnChainTransferAmount<BigUInt>,
        feeAmount: BigUInt,
        claimingAccountId: AccountId?
    ) -> ClaimableGiftDescription {
        let giftAmount = onChainAmountWithFee.map { $0 - feeAmount }

        return ClaimableGiftDescription(
            seed: claimableGift.seed,
            accountId: claimableGift.accountId,
            amount: giftAmount,
            chainAsset: claimableGift.chainAsset,
            claimingAccountId: claimingAccountId
        )
    }
}
