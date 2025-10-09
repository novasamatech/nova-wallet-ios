import Foundation

final class PendingNominatorState: BaseStashNextState {
    private(set) var nomination: Staking.Nomination?

    private(set) var ledgerInfo: Staking.Ledger?

    init(
        stateMachine: StakingStateMachineProtocol,
        commonData: StakingStateCommonData,
        stashItem: StashItem,
        ledgerInfo: Staking.Ledger?,
        nomination: Staking.Nomination?,
        totalReward: TotalRewardItem?,
        payee: Staking.RewardDestinationArg?,
        bagListNode: BagList.Node?
    ) {
        self.ledgerInfo = ledgerInfo
        self.nomination = nomination

        super.init(
            stateMachine: stateMachine,
            commonData: commonData,
            stashItem: stashItem,
            totalReward: totalReward,
            payee: payee,
            bagListNode: bagListNode
        )
    }

    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(ledgerInfo: Staking.Ledger?) {
        self.ledgerInfo = ledgerInfo

        if let ledgerInfo = ledgerInfo, let nomination = nomination {
            guard let stateMachine = stateMachine else {
                return
            }

            let newState = NominatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                nomination: nomination,
                totalReward: totalReward,
                payee: payee,
                bagListNode: bagListNode
            )

            stateMachine.transit(to: newState)
        } else {
            stateMachine?.transit(to: self)
        }
    }

    override func process(nomination: Staking.Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo, let nomination = nomination {
            newState = NominatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                nomination: nomination,
                totalReward: totalReward,
                payee: payee,
                bagListNode: bagListNode
            )
        } else if let ledgerInfo = ledgerInfo {
            newState = BondedState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                totalReward: totalReward,
                payee: payee,
                bagListNode: bagListNode
            )
        } else if let nomination = nomination {
            self.nomination = nomination

            newState = self
        } else {
            newState = PendingBondedState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                totalReward: totalReward,
                payee: payee,
                bagListNode: bagListNode
            )
        }

        stateMachine.transit(to: newState)
    }

    override func process(validatorPrefs: Staking.ValidatorPrefs?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo, let prefs = validatorPrefs {
            newState = ValidatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                prefs: prefs,
                totalReward: totalReward,
                payee: payee
            )
        } else if let prefs = validatorPrefs {
            newState = PendingValidatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                prefs: prefs,
                totalReward: totalReward,
                payee: payee
            )
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }
}
