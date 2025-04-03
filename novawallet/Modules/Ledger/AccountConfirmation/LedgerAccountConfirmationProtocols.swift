import Foundation

protocol LedgerAccountConfirmationViewProtocol: ControllerBackedProtocol {
    func didAddAccount(viewModel: LedgerAccountViewModel)
    func didReceive(networkViewModel: NetworkViewModel)
    func didStartLoading()
    func didStopLoading()
}

protocol LedgerAccountConfirmationPresenterProtocol: AnyObject {
    func setup()
    func selectAccount(at index: Int)
    func loadNext()
}

protocol LedgerAccountConfirmationInteractorInputProtocol: AnyObject {
    func fetchAccount(for index: UInt32)
    func confirm(address: AccountAddress, at index: UInt32)
    func cancelRequest()
}

protocol LedgerAccountConfirmationInteractorOutputProtocol: AnyObject {
    func didReceiveAccount(result: Result<LedgerAccountAmount, Error>, at index: UInt32)
    func didReceiveConfirmation(result: Result<AccountId, Error>, at index: UInt32)
}

protocol LedgerAccountConfirmationWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, LedgerErrorPresentable {
    func showAddressVerification(
        on view: LedgerAccountConfirmationViewProtocol?,
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        address: AccountAddress,
        cancelClosure: @escaping () -> Void
    )

    func complete(on view: LedgerAccountConfirmationViewProtocol?)
}
