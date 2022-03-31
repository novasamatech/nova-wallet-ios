import SoraFoundation

protocol SignerConnectViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: SignerConnectViewModel)
    func didReceive(status: SignerConnectStatus)
}

protocol SignerConnectPresenterProtocol: AnyObject {
    func setup()
    func presentAccountOptions()
    func presentConnectionDetails()
}

protocol SignerConnectInteractorInputProtocol: AnyObject {
    func setup()
    func connect()
    func processSigning(response: DAppOperationResponse, for request: DAppOperationRequest)
}

protocol SignerConnectInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceiveApp(metadata: BeaconConnectionInfo)
    func didReceiveConnection(result: Result<Void, Error>)
    func didReceive(request: DAppOperationRequest, signingType: DAppSigningType)
    func didSubmitOperation()
    func didReceiveProtocol(error: Error)
}

protocol SignerConnectWireframeProtocol: AlertPresentable, ErrorPresentable, AddressOptionsPresentable {
    func showConfirmation(
        from view: SignerConnectViewProtocol?,
        request: DAppOperationRequest,
        signingType: DAppSigningType,
        delegate: DAppOperationConfirmDelegate
    )

    func presentOperationSuccess(from view: SignerConnectViewProtocol?, locale: Locale)
}
