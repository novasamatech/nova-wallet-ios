import CommonWallet
protocol OperationDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: OperationDetailsViewModel)
}

protocol OperationDetailsPresenterProtocol: AnyObject {
    func setup()

    func showSenderActions()
    func showRecepientActions()
    func showOperationActions()
    func send()
}

protocol OperationDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol OperationDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveDetails(result: Result<OperationDetailsModel, Error>)
}

protocol OperationDetailsWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, OperationIdOptionsPresentable {
    func showSend(
        from view: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    )
}
