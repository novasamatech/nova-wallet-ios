import Foundation

final class PendingBondedState: BaseStashNextState {
    override func accept(visitor: StakingStateVisitorProtocol) {
        visitor.visit(state: self)
    }

    override func process(ledgerInfo: Staking.Ledger?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let ledgerInfo = ledgerInfo {
            newState = BondedState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: ledgerInfo,
                totalReward: totalReward,
                payee: payee,
                bagListNode: bagListNode
            )
        } else {
            newState = self
        }

        stateMachine.transit(to: newState)
    }

    override func process(nomination: Staking.Nomination?) {
        guard let stateMachine = stateMachine else {
            return
        }

        let newState: StakingStateProtocol

        if let nomination = nomination {
            newState = PendingNominatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: nil,
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
            newState = PendingValidatorState(
                stateMachine: stateMachine,
                commonData: commonData,
                stashItem: stashItem,
                ledgerInfo: nil,
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
