import BigInt

typealias DelegatedSignValidationCompletion = (Bool) -> Void

protocol ProxySignValidationPresenterProtocol: AnyObject {
    func setup()
}

protocol ProxySignValidationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ProxySignValidationInteractorOutputProtocol: AnyObject {
    func didReceiveBalance(_ balance: AssetBalance)
    func didReceiveBalanceExistense(_ balanceExistence: AssetBalanceExistence)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveError(_ error: Error)
}

protocol ProxySignValidationWireframeProtocol: AlertPresentable, ErrorPresentable, ProxyErrorPresentable {}
