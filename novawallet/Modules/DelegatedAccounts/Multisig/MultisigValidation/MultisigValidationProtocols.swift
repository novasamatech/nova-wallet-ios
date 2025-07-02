import BigInt

protocol MultisigValidationPresenterProtocol: AnyObject {
    func setup()
}

protocol MultisigValidationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol MultisigValidationInteractorOutputProtocol: AnyObject {
    func didReceiveBalances(_ balances: [AccountId: AssetBalance])
    func didReceiveBalanceExistense(_ balanceExistence: AssetBalanceExistence)
    func didReceiveFee(_ fee: ExtrinsicFeeProtocol)
    func didReceiveDeposit(_ deposit: BigUInt)
    func didReceiveError(_ error: Error)
}

protocol MultisigValidationWireframeProtocol: AlertPresentable, ErrorPresentable, MultisigErrorPresentable {}
