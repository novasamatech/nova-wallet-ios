import SoraFoundation

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didRecieve(viewModel: LocalizableResource<PayoutConfirmViewModel>)
    func didRecieve(amountViewModel: LocalizableResource<BalanceViewModelProtocol>)
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func presentAccountOptions()
}

protocol StakingPayoutConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func submitPayout()
    func estimateFee()
}

protocol StakingPayoutConfirmationInteractorOutputProtocol: AnyObject {
    func didRecieve(account: MetaChainAccountResponse, rewardAmount: Decimal)

    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)

    func didReceiveFee(result: Result<Decimal, Error>)

    func didStartPayout()
    func didCompletePayout(txHashes: [String])
    func didFailPayout(error: Error)
}

protocol StakingPayoutConfirmationWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable {
    func complete(from view: StakingPayoutConfirmationViewProtocol?)
}
