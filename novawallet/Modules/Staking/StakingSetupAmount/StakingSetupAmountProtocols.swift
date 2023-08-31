import Foundation
import BigInt

protocol StakingSetupAmountViewProtocol: ControllerBackedProtocol {
    func didReceive(balance: TitleHorizontalMultiValueView.Model)
    func didReceive(title: String)
    func didReceiveButtonState(title: String, enabled: Bool)
    func didReceiveInputChainAsset(viewModel: ChainAssetViewModel)
    func didReceiveAmount(inputViewModel: AmountInputViewModelProtocol)
    func didReceiveAmountInputPrice(viewModel: String?)
    func didReceive(stakingType: LoadableViewModelState<StakingTypeViewModel>?)
}

protocol StakingSetupAmountPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func updateAmount(_ newValue: Decimal?)
    func selectAmountPercentage(_ percentage: Float)
    func selectStakingType()
}

protocol StakingSetupAmountInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
    func remakeRecommendationSetup()
    func retryExistentialDeposit()

    func estimateFee(for staking: SelectedStakingOption, amount: BigUInt, feeId: TransactionFeeId)
    func updateRecommendation(for amount: BigUInt)
}

protocol StakingSetupAmountInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance)
    func didReceive(fee: BigUInt?, feeId: TransactionFeeId)
    func didReceive(recommendation: RelaychainStakingRecommendation, amount: BigUInt)
    func didReceive(existentialDeposit: BigUInt)
    func didReceive(locks: AssetLocks)
    func didReceive(error: StakingSetupAmountError)
}

protocol StakingSetupAmountWireframeProtocol: AlertPresentable, ErrorPresentable, FeeRetryable,
    CommonRetryable, StakingErrorPresentable, NominationPoolErrorPresentable {
    func showStakingTypeSelection(
        from view: ControllerBackedProtocol?,
        method: StakingSelectionMethod,
        amount: BigUInt,
        delegate: StakingTypeDelegate?
    )

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        stakingOption: SelectedStakingOption,
        amount: Decimal
    )

    func showSelectValidators(from view: ControllerBackedProtocol?, selectedValidators: PreparedValidators)
}

enum StakingSetupAmountError: Error {
    case assetBalance(Error)
    case price(Error)
    case fee(Error, TransactionFeeId)
    case recommendation(Error)
    case locks(Error)
    case existentialDeposit(Error)
}
