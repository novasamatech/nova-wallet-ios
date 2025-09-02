import Foundation
import Foundation_iOS

protocol StakingParachainInteractorInputProtocol: AnyObject {
    func setup()
    func fetchScheduledRequests()
    func fetchDelegations(for collators: [AccountId])
    func update(totalRewardFilter: StakingRewardFiltersPeriod)
}

protocol StakingParachainInteractorOutputProtocol: AnyObject {
    func didReceiveChainAsset(_ chainAsset: ChainAsset)
    func didReceiveAccount(_ account: MetaChainAccountResponse?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveScheduledRequests(_ requests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceiveDelegations(_ delegations: [ParachainStkCollatorSelectionInfo])
    func didReceiveSelectedCollators(_ collatorsInfo: SelectedRoundCollators)
    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol)
    func didReceiveNetworkInfo(_ networkInfo: ParachainStaking.NetworkInfo)
    func didReceiveStakingDuration(_ stakingDuration: ParachainStakingDuration)
    func didReceiveBlockNumber(_ blockNumber: BlockNumber?)
    func didReceiveRoundInfo(_ roundInfo: ParachainStaking.RoundInfo?)
    func didReceiveTotalReward(_ totalReward: TotalRewardItem?)
    func didReceiveYieldBoost(state: ParaStkYieldBoostState)
    func didReceiveError(_ error: Error)
}

protocol StakingParachainWireframeProtocol: AlertPresentable, ErrorPresentable, ParachainStakingErrorPresentable {
    func showStakeTokens(
        from view: ControllerBackedProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    )

    func showUnstakeTokens(
        from view: ControllerBackedProtocol?,
        initialDelegator: ParachainStaking.Delegator?,
        initialScheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?,
        delegationIdentities: [AccountId: AccountIdentity]?
    )

    func showYourCollators(from view: ControllerBackedProtocol?)

    func showRedeemTokens(from view: ControllerBackedProtocol?)

    func showUnstakingCollatorSelection(
        from view: ControllerBackedProtocol?,
        delegate: ModalPickerViewControllerDelegate,
        viewModels: [LocalizableResource<AccountDetailsSelectionViewModel>],
        context: AnyObject?
    )

    func showRebondTokens(
        from view: ControllerBackedProtocol?,
        collatorId: AccountId,
        collatorIdentity: AccountIdentity?
    )

    func showYieldBoost(from view: ControllerBackedProtocol?, initData: ParaStkYieldBoostInitState)
}
