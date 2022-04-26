import SoraFoundation
import CommonWallet
import BigInt

protocol StakingBondMoreConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingBondMoreConfirmViewModel)
    func didReceiveAmount(viewModel: LocalizableResource<BalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingBondMoreConfirmationPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingBondMoreConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func submit(for amount: Decimal)
    func estimateFee(for amount: Decimal)
}

protocol StakingBondMoreConfirmationOutputProtocol: AnyObject {
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveStash(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)

    func didSubmitBonding(result: Result<String, Error>)
}

protocol StakingBondMoreConfirmationWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable {
    func complete(from view: StakingBondMoreConfirmationViewProtocol?)
}
