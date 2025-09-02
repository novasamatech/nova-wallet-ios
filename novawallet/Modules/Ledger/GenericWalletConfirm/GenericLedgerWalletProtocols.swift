import Operation_iOS

protocol GenericLedgerWalletInteractorInputProtocol: AnyObject {
    func setup()
    func fetchAccount()
    func confirmAccount()
    func cancelRequest()
}

protocol GenericLedgerWalletInteractorOutputProtocol: AnyObject {
    func didReceive(model: PolkadotLedgerWalletModel)
    func didReceiveAccountConfirmation()
    func didReceiveChains(changes: [DataProviderChange<ChainModel>])
    func didReceive(error: GenericWalletConfirmInteractorError)
}

protocol GenericLedgerWalletWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable,
    LedgerErrorPresentable, CommonRetryable {
    func showAddressVerification(
        on view: HardwareWalletAddressesViewProtocol?,
        deviceName: String,
        deviceModel: LedgerDeviceModel,
        addresses: [HardwareWalletAddressScheme: AccountAddress],
        cancelClosure: @escaping () -> Void
    )

    func procced(from view: HardwareWalletAddressesViewProtocol?, walletModel: PolkadotLedgerWalletModel)
}
