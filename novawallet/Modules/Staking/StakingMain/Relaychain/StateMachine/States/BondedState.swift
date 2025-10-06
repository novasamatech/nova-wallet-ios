import Foundation

final class BondedState: BaseStashNextState, StashLedgerStateProtocol {
    private(set) var ledgerInfo: Staking.Ledger

    init(
        stateMachine: StakingStateMachineProtocol,
        commonData: StakingStateCommonData,
        stashItem: StashItem,
        ledgerInfo: Staking.Ledger,
        totalReward: TotalRewardItem?,
        payee: Staking.RewardDestinationArg?,
        bagListNode: BagList.Node?
    ) {
        self.ledgerInfo = ledgerInfo

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
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo {
            self.ledgerInfo = ledgerInfo

            newState = self
        } else {
            newState = StashState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: nil,
                totalReward: totalReward,
                bagListNode: bagListNode
            )
        }

        stateMachine.transit(to: newState)
    }

    override func process(nomination: Staking.Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let nomination = nomination {
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
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }

    override func process(validatorPrefs: Staking.ValidatorPrefs?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let prefs = validatorPrefs {
            newState = ValidatorState(
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
