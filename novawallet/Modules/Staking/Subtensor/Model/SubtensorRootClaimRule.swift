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

    static func isClaimable(_ preview: SubtensorRootClaimPreview, minimumClaim: Balance) -> Bool {
        preview.redeemable > 0 && preview.redeemable >= minimumClaim
    }

    static func target(
        in claimable: SubtensorRootClaimable,
        excluding hotkeys: Set<AccountId>
    ) -> SubtensorRootClaimPreview? {
        guard let minimumClaim = claimable.minimumClaim else {
            return nil
        }

        return claimable.previews
            .filter { !hotkeys.contains($0.hotkey) && isClaimable($0, minimumClaim: minimumClaim) }
            .min(by: isOrderedBefore)
    }

    static func otherClaimableCount(in claimable: SubtensorRootClaimable, target: AccountId) -> Int {
        guard let minimumClaim = claimable.minimumClaim else {
            return 0
        }

        return claimable.previews.filter { preview in
            preview.hotkey != target && isClaimable(preview, minimumClaim: minimumClaim)
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
