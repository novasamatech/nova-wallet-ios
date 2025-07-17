import Foundation_iOS

protocol StakingRewardDestConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRewardDestConfirmViewModel)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingRewardDestConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func presentSenderAccountOptions()
    func presentPayoutAccountOptions()
}

protocol StakingRewardDestConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem)
    func submit(rewardDestination: RewardDestination<AccountAddress>, for stashItem: StashItem)
}

protocol StakingRewardDestConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveController(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveAccountBalance(result: Result<AssetBalance?, Error>)
    func didSubmitRewardDest(result: Result<ExtrinsicSubmittedModel, Error>)
}

protocol StakingRewardDestConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable, MessageSheetPresentable, ExtrinsicSigningErrorHandling {
    func complete(from view: StakingRewardDestConfirmViewProtocol?)
}
