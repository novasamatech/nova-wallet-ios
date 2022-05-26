import BigInt
import CommonWallet
import Foundation

protocol ParaStkStakeSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveCollator(viewModel: DisplayAddressViewModel?)
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

    // TODO: Replace with manual collator selection
    func rotateSelectedCollator()
    func estimateFee(
        _ amount: BigUInt,
        collator: AccountId?,
        collatorDelegationsCount: UInt32,
        delegationsCount: UInt32
    )
}

protocol ParaStkStakeSetupInteractorOutputProtocol: AnyObject {
    func didReceiveAssetBalance(_ balance: AssetBalance?)
    func didReceiveRewardCalculator(_ calculator: ParaStakingRewardCalculatorEngineProtocol)
    func didReceivePrice(_ priceData: PriceData?)
    func didReceiveFee(_ result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveCollator(
        metadata: ParachainStaking.CandidateMetadata?,
        address: DisplayAddress
    )

    func didReceiveMinTechStake(_ minStake: BigUInt)

    func didReceiveDelegator(_ delegator: ParachainStaking.Delegator?)

    func didCompleteSetup()
    func didReceiveError(_ error: Error)
}

protocol ParaStkStakeSetupWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    ParachainStakingErrorPresentable {
    func showConfirmation(
        from view: ParaStkStakeSetupViewProtocol?,
        collator: DisplayAddress,
        amount: Decimal
    )

    func showCollatorSelection(from view: ParaStkStakeSetupViewProtocol?)
}
