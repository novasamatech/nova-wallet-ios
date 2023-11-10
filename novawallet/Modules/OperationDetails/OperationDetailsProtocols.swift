protocol OperationDetailsViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: OperationDetailsViewModel)
}

protocol OperationDetailsPresenterProtocol: AnyObject {
    func setup()

    func showSenderActions()
    func showRecepientActions()
    func showOperationActions()
    func send()
    func showRateInfo()
    func showNetworkFeeInfo()
    func repeatOperation()
}

protocol OperationDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol OperationDetailsInteractorOutputProtocol: AnyObject {
    func didReceiveDetails(result: Result<OperationDetailsModel, Error>)
}

protocol OperationDetailsWireframeProtocol: AlertPresentable, ErrorPresentable,
    AddressOptionsPresentable, OperationIdOptionsPresentable, ShortTextInfoPresentable {
    func showSend(
        from view: OperationDetailsViewProtocol?,
        displayAddress: DisplayAddress,
        chainAsset: ChainAsset
    )

    func showSwapSetup(
        from: OperationDetailsViewProtocol?,
        state: SwapSetupInitState
    )
}
