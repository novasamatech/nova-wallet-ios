protocol GenericLedgerAddEvmInteractorInputProtocol: AnyObject {
    func loadAccounts(at index: UInt32)
    func confirm(index: UInt32)
    func cancelConfirmation()
}

protocol GenericLedgerAddEvmInteractorOutputProtocol: AnyObject {
    func didReceive(account: GenericLedgerAccountModel)
    func didUpdateWallet()
    func didReceive(error: GenericLedgerAddEvmInteractorError)
}

protocol GenericLedgerAddEvmWireframeProtocol: AlertPresentable, ErrorPresentable,
    CommonRetryable, LedgerErrorPresentable, AddressOptionsPresentable, MessageSheetPresentable {
    func showAddressVerification(
        on view: ControllerBackedProtocol?,
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        address: AccountAddress,
        cancelClosure: @escaping () -> Void
    )

    func proceed(on view: ControllerBackedProtocol?)
}

enum GenericLedgerAddEvmInteractorError: Error {
    case accountFailed(Error)
    case updateFailed(Error, UInt32)
}
