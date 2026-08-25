import BigInt
import Foundation

struct SubtensorClaimRewardsState: Equatable {
    let claimable: SubtensorRootClaimable
    let threshold: Balance

    var eligiblePositions: [SubtensorStakingPallet.RootBasketPosition] {
        claimable.positions.filter { $0.payout > 0 && $0.payout >= threshold }
    }

    var eligibleHotkeys: [AccountId] {
        eligiblePositions.map(\.hotkey)
    }

    var eligibleTotal: Balance {
        eligiblePositions.reduce(Balance.zero) { $0 + $1.payout }
    }

    var pendingTotal: Balance {
        claimable.positions
            .filter { $0.payout > 0 && $0.payout < threshold }
            .reduce(Balance.zero) { $0 + $1.payout }
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
