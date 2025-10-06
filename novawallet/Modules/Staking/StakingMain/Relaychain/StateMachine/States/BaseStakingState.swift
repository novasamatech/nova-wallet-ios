import Foundation
import BigInt

class BaseStakingState: StakingStateProtocol {
    weak var stateMachine: StakingStateMachineProtocol?

    private(set) var commonData: StakingStateCommonData

    init(
        stateMachine: StakingStateMachineProtocol?,
        commonData: StakingStateCommonData
    ) {
        self.stateMachine = stateMachine
        self.commonData = commonData
    }

    func accept(visitor _: StakingStateVisitorProtocol) {}

    func process(chainAsset: ChainAsset?) {
        if commonData.chainAsset != chainAsset {
            commonData = StakingStateCommonData.empty.byReplacing(chainAsset: chainAsset)

            guard let stateMachine = stateMachine else {
                return
            }

            let newState = InitialStakingState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine.transit(to: newState)
        }
    }

    func process(address: String?) {
        if commonData.address != address {
            commonData = commonData
                .byReplacing(address: address)
                .byReplacing(accountBalance: nil)

            guard let stateMachine = stateMachine else {
                return
            }

            let newState = InitialStakingState(
                stateMachine: stateMachine,
                commonData: commonData
            )

            stateMachine.transit(to: newState)
        }
    }

    func process(accountBalance: AssetBalance?) {
        commonData = commonData.byReplacing(accountBalance: accountBalance)

        stateMachine?.transit(to: self)
    }

    func process(price: PriceData?) {
        commonData = commonData.byReplacing(price: price)

        stateMachine?.transit(to: self)
    }

    func process(calculator: RewardCalculatorEngineProtocol?) {
        commonData = commonData.byReplacing(calculatorEngine: calculator)

        stateMachine?.transit(to: self)
    }

    func process(eraStakersInfo: EraStakersInfo?) {
        commonData = commonData.byReplacing(eraStakersInfo: eraStakersInfo)

        stateMachine?.transit(to: self)
    }

    func process(minStake: BigUInt?) {
        commonData = commonData.byReplacing(minStake: minStake)

        stateMachine?.transit(to: self)
    }

    func process(maxNominatorsPerValidator: UInt32?) {
        commonData = commonData.byReplacing(maxNominatorsPerValidator: maxNominatorsPerValidator)

        stateMachine?.transit(to: self)
    }

    func process(minNominatorBond: BigUInt?) {
        commonData = commonData.byReplacing(minNominatorBond: minNominatorBond)

        stateMachine?.transit(to: self)
    }

    func process(counterForNominators: UInt32?) {
        commonData = commonData.byReplacing(counterForNominators: counterForNominators)

        stateMachine?.transit(to: self)
    }

    func process(maxNominatorsCount: UInt32?) {
        commonData = commonData.byReplacing(maxNominatorsCount: maxNominatorsCount)

        stateMachine?.transit(to: self)
    }

    func process(bagListSize: UInt32?) {
        commonData = commonData.byReplacing(bagListSize: bagListSize)

        stateMachine?.transit(to: self)
    }

    func process(bagListScoreFactor: BigUInt?) {
        if bagListScoreFactor != commonData.bagListScoreFactor {
            commonData = commonData.byReplacing(bagListScoreFactor: bagListScoreFactor)

            stateMachine?.transit(to: self)
        }
    }

    func process(stashItem _: StashItem?) {}
    func process(ledgerInfo _: Staking.Ledger?) {}
    func process(nomination _: Staking.Nomination?) {}
    func process(validatorPrefs _: Staking.ValidatorPrefs?) {}
    func process(totalReward _: TotalRewardItem?) {}
    func process(payee _: Staking.RewardDestinationArg?) {}
    func process(bagListNode _: BagList.Node?) {}

    func process(eraCountdown: EraCountdown) {
        commonData = commonData.byReplacing(eraCountdown: eraCountdown)

        stateMachine?.transit(to: self)
    }

    func process(totalRewardFilter: StakingRewardFiltersPeriod?) {
        commonData = commonData.byReplacing(totalRewardFilter: totalRewardFilter)

        stateMachine?.transit(to: self)
    }

    func process(proxy: ProxyDefinition?) {
        commonData = commonData.byReplacing(proxy: proxy)

        stateMachine?.transit(to: self)
    }
}
