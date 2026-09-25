import BigInt
import Foundation

struct SubtensorClaimRewardsState: Equatable {
    let claimable: SubtensorRootClaimable
    let threshold: Balance

    var eligiblePositions: [SubtensorRootClaimPreview] {
        claimable.previews.filter { $0.redeemable > 0 && $0.redeemable >= threshold }
    }

    var eligibleHotkeys: [AccountId] {
        eligiblePositions.map(\.hotkey)
    }

    var eligibleTotal: Balance {
        eligiblePositions.reduce(Balance.zero) { $0 + $1.redeemable }
    }

    var pendingTotal: Balance {
        claimable.previews
            .filter { $0.redeemable > 0 && $0.redeemable < threshold }
            .reduce(Balance.zero) { $0 + $1.redeemable }
    }

    func totalFee(from singleClaimFee: ExtrinsicFeeProtocol) -> ExtrinsicFeeProtocol {
        ExtrinsicFee(
            amount: singleClaimFee.amount * Balance(eligibleHotkeys.count),
            payer: singleClaimFee.payer,
            weight: singleClaimFee.weight
        )
    }
}

extension SubtensorRootClaimable {
    func claimState(threshold: Balance) -> SubtensorClaimRewardsState {
        SubtensorClaimRewardsState(claimable: self, threshold: threshold)
    }
}
