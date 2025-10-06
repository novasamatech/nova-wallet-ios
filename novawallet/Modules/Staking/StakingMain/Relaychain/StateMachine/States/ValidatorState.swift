import Foundation

final class ValidatorState: BaseStashNextState, StashLedgerStateProtocol {
    private(set) var ledgerInfo: Staking.Ledger
    private(set) var prefs: Staking.ValidatorPrefs

    init(
        stateMachine: StakingStateMachineProtocol,
        commonData: StakingStateCommonData,
        stashItem: StashItem,
        ledgerInfo: Staking.Ledger,
        prefs: Staking.ValidatorPrefs,
        totalReward: TotalRewardItem?,
        payee: Staking.RewardDestinationArg?
    ) {
        self.ledgerInfo = ledgerInfo
        self.prefs = prefs

        super.init(
            stateMachine: stateMachine,
            commonData: commonData,
            stashItem: stashItem,
            totalReward: totalReward,
            payee: payee,
            bagListNode: nil
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
            self.prefs = prefs

            newState = self
        } else {
            newState = BondedState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                totalReward: totalReward,
                payee: payee,
                bagListNode: bagListNode
            )
        }

        stateMachine.transit(to: newState)
    }
}
