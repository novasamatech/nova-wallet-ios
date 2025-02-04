import Foundation

struct MythosStakingBalanceState {
    let balance: AssetBalance
    let frozenBalance: MythosStakingFrozenBalance
    let stakingDetails: MythosStakingDetails?
    let currentBlock: BlockNumber

    init?(
        balance: AssetBalance?,
        frozenBalance: MythosStakingFrozenBalance?,
        stakingDetails: MythosStakingDetails?,
        currentBlock: BlockNumber?
    ) {
        guard
            let balance = balance,
            let frozenBalance = frozenBalance,
            let currentBlock = currentBlock
        else {
            return nil
        }

        self.balance = balance
        self.frozenBalance = frozenBalance
        self.stakingDetails = stakingDetails
        self.currentBlock = currentBlock
    }

    var totalStaked: Balance {
        stakingDetails?.totalStake ?? 0
    }

    var unavailableDueUnstake: Balance {
        if
            let lastUnstake = stakingDetails?.maybeLastUnstake,
            lastUnstake.blockNumber > currentBlock {
            return lastUnstake.amount
        } else {
            return 0
        }
    }

    func stakableAmount() -> Balance {
        let frozenButNotStaked = frozenBalance.staking.subtractOrZero(totalStaked)

        let availableAmount = balance.freeInPlank.subtractOrZero(frozenBalance.total) + frozenButNotStaked

        return availableAmount.subtractOrZero(unavailableDueUnstake)
    }

    func deriveStakeAmountModel(for amount: Balance) -> MythosStakeModel.Amount? {
        guard stakableAmount() >= amount else {
            return nil
        }

        let availableStakedAmount = frozenBalance.staking.subtractOrZero(totalStaked + unavailableDueUnstake)

        return MythosStakeModel.Amount(
            toLock: amount.subtractOrZero(availableStakedAmount),
            toStake: amount
        )
    }
}
