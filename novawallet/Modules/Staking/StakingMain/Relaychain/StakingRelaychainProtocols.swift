import Foundation
import BigInt

protocol StakingRelaychainInteractorInputProtocol: AnyObject {
    func setup()
    func update(totalRewardFilter: StakingRewardFiltersPeriod)
}

protocol StakingRelaychainInteractorOutputProtocol: AnyObject {
    func didReceive(selectedAddress: String)
    func didReceive(price: PriceData?)
    func didReceive(priceError: Error)
    func didReceive(totalReward: TotalRewardItem)
    func didReceive(totalRewardError: Error)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(balanceError: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
    func didReceive(stashItem: StashItem?)
    func didReceive(stashItemError: Error)
    func didReceive(ledgerInfo: Staking.Ledger?)
    func didReceive(ledgerInfoError: Error)
    func didReceive(nomination: Staking.Nomination?)
    func didReceive(nominationError: Error)
    func didReceive(validatorPrefs: Staking.ValidatorPrefs?)
    func didReceive(validatorError: Error)
    func didReceive(eraStakersInfo: EraStakersInfo)
    func didReceive(eraStakersInfoError: Error)
    func didReceive(networkStakingInfo: NetworkStakingInfo)
    func didReceive(networkStakingInfoError: Error)
    func didReceive(payee: Staking.RewardDestinationArg?)
    func didReceive(payeeError: Error)
    func didReceive(newChainAsset: ChainAsset)
    func didReceiveMinNominatorBond(result: Result<BigUInt?, Error>)
    func didReceiveCounterForNominators(result: Result<UInt32?, Error>)
    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>)
    func didReceiveBagListSize(result: Result<UInt32?, Error>)
    func didReceiveBagListNode(result: Result<BagList.Node?, Error>)
    func didReceiveBagListScoreFactor(result: Result<BigUInt?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)

    func didReceiveMaxNominatorsPerValidator(result: Result<UInt32?, Error>)

    func didReceiveAccount(_ account: MetaChainAccountResponse?, for accountId: AccountId)
    func didReceiveProxy(result: Result<ProxyDefinition?, Error>)
}

protocol StakingRelaychainWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func proceedToSelectValidatorsStart(
        from view: StakingMainViewProtocol?,
        existingBonding: ExistingBonding
    )

    func showRewardPayoutsForNominator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress)
    func showRewardPayoutsForValidator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress)
    func showNominatorValidators(from view: ControllerBackedProtocol?)
    func showRewardDestination(from view: ControllerBackedProtocol?)
    func showControllerAccount(from view: ControllerBackedProtocol?)

    func showBondMore(from view: ControllerBackedProtocol?)
    func showUnbond(from view: ControllerBackedProtocol?)
    func showRedeem(from view: ControllerBackedProtocol?)
    func showRebond(from view: ControllerBackedProtocol?, option: StakingRebondOption)
    func showRebagConfirm(from view: ControllerBackedProtocol?)

    func showYourValidatorInfo(_ stashAddress: AccountAddress, from view: ControllerBackedProtocol?)
    func showAddProxy(from view: ControllerBackedProtocol?)
    func showEditProxies(from view: ControllerBackedProtocol?)
}
