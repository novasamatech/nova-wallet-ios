import BigInt

protocol DSFeeValidationPresenterProtocol: AnyObject {
    func setup()
}

protocol DSFeeValidationInteractorInputProtocol: AnyObject {
    func setup()
    func updateDataForNextValidation(
        balance: AssetBalance,
        fee: ExtrinsicFeeProtocol?
    )
}

protocol DSFeeValidationInteractorOutputProtocol: AnyObject {
    func didReceiveBalance(_ balance: AssetBalance)
    func didReceiveBalanceExistense(_ balanceExistence: AssetBalanceExistence)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveError(_ error: Error)
}

protocol DSFeeValidationWireframeProtocol: AlertPresentable, ErrorPresentable {}
