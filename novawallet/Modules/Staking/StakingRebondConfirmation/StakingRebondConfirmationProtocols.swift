import Foundation
import SoraFoundation
import BigInt

protocol StakingRebondConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRebondConfirmationViewModel)
    func didReceiveAmount(viewModel: LocalizableResource<BalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingRebondConfirmationPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func selectAccount()
}

protocol StakingRebondConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func submit(for amount: Decimal)
    func estimateFee(for amount: Decimal)
}

protocol StakingRebondConfirmationInteractorOutputProtocol: AnyObject {
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveController(result: Result<MetaChainAccountResponse?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)

    func didSubmitRebonding(result: Result<String, Error>)
}

protocol StakingRebondConfirmationWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func complete(from view: StakingRebondConfirmationViewProtocol?)
}
