import BigInt
import CommonWallet

protocol ParaStkYieldBoostSetupViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveCollator(viewModel: AccountDetailsSelectionViewModel?)
    func didReceiveRewardComparison(viewModel: ParaStkYieldBoostComparisonViewModel)
    func didReceiveYieldBoostSelected(_ isSelected: Bool)
    func didReceiveYieldBoostPeriod(viewModel: ParaStkYieldBoostPeriodViewModel?)
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
}

protocol ParaStkYieldBoostSetupPresenterProtocol: AnyObject {
    func setup()
    func switchRewardsOption(to isYieldBoosted: Bool)
    func updateThresholdAmount(_ newValue: Decimal?)
    func selectThresholdAmountPercentage(_ percentage: Float)
    func selectCollator()
    func proceed()
}

protocol ParaStkYieldBoostSetupInteractorInputProtocol: AnyObject {
    func setup()
    func requestParams(for stake: BigUInt, collator: AccountId)
}

protocol ParaStkYieldBoostSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceiveYieldBoostTasks(_ tasks: [ParaStkYieldBoostState.Task])
    func didReceiveYieldBoostParams(_ params: ParaStkYieldBoostResponse, stake: BigUInt, collator: AccountId)
    func didReceiveError(_ error: ParaStkYieldBoostSetupInteractorError)
}

protocol ParaStkYieldBoostSetupWireframeProtocol: AnyObject {
    func showDelegationSelection(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )
}
