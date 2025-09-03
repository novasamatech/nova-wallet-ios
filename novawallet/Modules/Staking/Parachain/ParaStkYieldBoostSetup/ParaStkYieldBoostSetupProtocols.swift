import Foundation
import BigInt

protocol ParaStkYieldBoostSetupViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveCollator(viewModel: AccountDetailsSelectionViewModel?)
    func didReceiveRewardComparison(viewModel: ParaStkYieldBoostComparisonViewModel)
    func didReceiveYieldBoostSelected(_ isSelected: Bool)
    func didReceiveYieldBoostPeriod(viewModel: ParaStkYieldBoostPeriodViewModel?)
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveNetworkFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveHasChanges(viewModel: Bool)
}

protocol ParaStkYieldBoostSetupPresenterProtocol: AnyObject {
    func setup()
    func switchRewardsOption(to isYieldBoosted: Bool)
    func updateThresholdAmount(_ newValue: Decimal?)
    func selectThresholdAmountPercentage(_ percentage: Float)
    func selectCollator()
    func proceed()
}

protocol ParaStkYieldBoostSetupInteractorInputProtocol: ParaStkYieldBoostScheduleInteractorInputProtocol,
    ParaStkYieldBoostCancelInteractorInputProtocol {
    func setup()
    func requestParams(for stake: BigUInt, collator: AccountId)
    func retrySubscriptions()
    func fetchIdentities(for collators: [AccountId])
    func fetchRewardCalculator()
}

protocol ParaStkYieldBoostSetupInteractorOutputProtocol: ParaStkYieldBoostScheduleInteractorOutputProtocol,
    ParaStkYieldBoostCancelInteractorOutputProtocol {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceiveRewardCalculator(_ calculator: CollatorStakingRewardCalculatorEngineProtocol)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
    func didReceiveScheduledRequests(_ scheduledRequests: [ParachainStaking.DelegatorScheduledRequest]?)
    func didReceiveYieldBoostTasks(_ tasks: [ParaStkYieldBoostState.Task])
    func didReceiveYieldBoostParams(_ params: ParaStkYieldBoostResponse, stake: BigUInt, collator: AccountId)
    func didReceiveError(_ error: ParaStkYieldBoostSetupInteractorError)
}

protocol ParaStkYieldBoostSetupWireframeProtocol: AlertPresentable, ErrorPresentable, CommonRetryable, FeeRetryable,
    ParaStkYieldBoostErrorPresentable {
    func showDelegationSelection(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )

    func showStartYieldBoostConfirmation(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        model: ParaStkYieldBoostConfirmModel
    )

    func showStopYieldBoostConfirmation(
        from view: ParaStkYieldBoostSetupViewProtocol?,
        collatorId: AccountId,
        collatorIdentity: AccountIdentity?
    )
}
