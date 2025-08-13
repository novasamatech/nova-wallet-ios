import Foundation
import BigInt

protocol StakingStateVisitorProtocol {
    func visit(state: InitialStakingState)
    func visit(state: StashState)
    func visit(state: PendingBondedState)
    func visit(state: BondedState)
    func visit(state: PendingNominatorState)
    func visit(state: NominatorState)
    func visit(state: PendingValidatorState)
    func visit(state: ValidatorState)
}

protocol StakingStateProtocol {
    func accept(visitor: StakingStateVisitorProtocol)

    func process(address: String?)
    func process(chainAsset: ChainAsset?)
    func process(accountBalance: AssetBalance?)
    func process(price: PriceData?)
    func process(calculator: RewardCalculatorEngineProtocol?)
    func process(stashItem: StashItem?)
    func process(ledgerInfo: Staking.Ledger?)
    func process(nomination: Staking.Nomination?)
    func process(validatorPrefs: Staking.ValidatorPrefs?)
    func process(eraStakersInfo: EraStakersInfo?)
    func process(totalReward: TotalRewardItem?)
    func process(payee: Staking.RewardDestinationArg?)
    func process(minStake: BigUInt?)
    func process(maxNominatorsPerValidator: UInt32?)
    func process(minNominatorBond: BigUInt?)
    func process(counterForNominators: UInt32?)
    func process(maxNominatorsCount: UInt32?)
    func process(bagListSize: UInt32?)
    func process(bagListNode: BagList.Node?)
    func process(bagListScoreFactor: BigUInt?)
    func process(eraCountdown: EraCountdown)
    func process(totalRewardFilter: StakingRewardFiltersPeriod?)
    func process(proxy: ProxyDefinition?)
}

protocol StakingStateMachineProtocol: AnyObject {
    var state: StakingStateProtocol { get }

    func transit(to state: StakingStateProtocol)
}

extension StakingStateMachineProtocol {
    func viewState<S: StakingStateProtocol, V>(using closure: (S) -> V?) -> V? {
        if let concreteState = state as? S {
            return closure(concreteState)
        } else {
            return nil
        }
    }
}

protocol StakingStateMachineDelegate: AnyObject {
    func stateMachineDidChangeState(_ stateMachine: StakingStateMachineProtocol)
}
