import BigInt
import CommonWallet
import Foundation

protocol ParaStkStakeSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveCollator(viewModel: AccountDetailsSelectionViewModel?)
    func didReceiveAssetBalance(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveMinStake(viewModel: BalanceViewModelProtocol?)
    func didReceiveReward(viewModel: StakingRewardInfoViewModel)
}

protocol ParaStkStakeSetupPresenterProtocol: AnyObject {
    func setup()
    func selectCollator()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func proceed()
}

protocol ParaStkStakeSetupInteractorInputProtocol: AnyObject {
    func setup()

    func applyCollator(with accountId: AccountId)
    func estimateFee(with callWrapper: DelegationCallWrapper)
}

protocol ParaStkStakeSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveCollator(metadata: ParachainStaking.CandidateMetadata?)
    func didReceiveMinTechStake(_ minStake: BigUInt)
    func didReceiveMinDelegationAmount(_ amount: BigUInt)
    func didReceiveMaxDelegations(_ maxDelegations: UInt32)
    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)
    func didReceiveDelegationIdentities(_ identities: [AccountId: AccountIdentity]?)
    func didReceiveError(_ error: Error)
}

protocol ParaStkStakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    ParachainStakingErrorPresentable {
    func showConfirmation(
        from view: ParaStkStakeSetupViewProtocol?,
        collator: DisplayAddress,
        amount: Decimal,
        initialDelegator: ParachainStaking.Delegator?
    )

    func showCollatorSelection(
        from view: ParaStkStakeSetupViewProtocol?,
        delegate: ParaStkSelectCollatorsDelegate
    )

    func showDelegationSelection(
        from view: ParaStkStakeSetupViewProtocol?,
        viewModels: [AccountDetailsPickerViewModel],
        selectedIndex: Int,
        delegate: ModalPickerViewControllerDelegate,
        context: AnyObject?
    )
}
