protocol ParitySignerTxScanViewProtocol: QRScannerViewProtocol {
    func didReceiveExpiration(viewModel: ExpirationTimeViewModel)
}

protocol ParitySignerTxScanPresenterProtocol: AnyObject {
    func setup()
}

protocol ParitySignerTxScanInteractorInputProtocol: AnyObject {}

protocol ParitySignerTxScanInteractorOutputProtocol: AnyObject {}

protocol ParitySignerTxScanWireframeProtocol: AlertPresentable, ErrorPresentable {}
