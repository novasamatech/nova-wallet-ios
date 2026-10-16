import Foundation
import BigInt

enum SubtensorRootClaimRule {
    static func minimumClaim(fromThresholdBits bits: Balance?) -> Balance {
        guard let bits else {
            return SubtensorStakingPallet.defaultRootClaimableThreshold
        }

        let fractionalBits = SubtensorStakingPallet.fixedPointFractionalBits
        let fractionalUnit = Balance(1) << fractionalBits

        return (bits + fractionalUnit - 1) >> fractionalBits
    }

    static func isClaimable(_ preview: SubtensorRootClaimPreview) -> Bool {
        preview.redeemable > 0 && preview.redeemable >= preview.minimumClaim
    }

    static func isFeeAbovePayout(fee: Balance, payout: Balance) -> Bool {
        fee > payout
    }

    static func target(
        in claimable: [SubtensorRootClaimPreview],
        excluding hotkeys: Set<AccountId>
    ) -> SubtensorRootClaimPreview? {
        claimable
            .filter { !hotkeys.contains($0.hotkey) && isClaimable($0) }
            .min(by: isOrderedBefore)
    }

    static func otherClaimableCount(in claimable: [SubtensorRootClaimPreview], target: AccountId) -> Int {
        claimable.filter { preview in
            preview.hotkey != target && isClaimable(preview)
        }.count
    }
}

private extension SubtensorRootClaimRule {
    static func isOrderedBefore(_ lhs: SubtensorRootClaimPreview, _ rhs: SubtensorRootClaimPreview) -> Bool {
        guard lhs.redeemable == rhs.redeemable else {
            return lhs.redeemable > rhs.redeemable
        }

        return lhs.hotkey.lexicographicallyPrecedes(rhs.hotkey)
    }
}
