import BigInt

protocol MultisigOpValidationPresenterProtocol: AnyObject {
    func setup()
}

protocol MOValidationInteractorInputProtocol: AnyObject {
    func setup()
    func reserve(deposit: Balance, balance: AssetBalance)
}

protocol MOValidationInteractorOutputProtocol: AnyObject {
    func didReceiveSignatoryBalance(_ balance: AssetBalance?)
    func didReceivePaidFee(_ fee: Balance?)
    func didReceiveDeposit(_ deposit: Balance)
    func didReceiveMultisigDefinition(_ definition: MultisigPallet.MultisigDefinition?)
    func didReceiveBalanceExistense(_ balanceExistence: AssetBalanceExistence)
    func didReceiveError(_ error: Error)
}

protocol MOValidationWireframeProtocol: AlertPresentable, ErrorPresentable, MultisigErrorPresentable {}
