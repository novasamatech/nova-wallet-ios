import BigInt

protocol OnChainTransferSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: BigUInt, recepient: AccountAddress?)
    func change(recepient: AccountAddress?)
}

protocol OnChainTransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveSendingAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetSenderBalance(_ balance: AssetBalance)
    func didReceiveSendingAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveUtilityAssetRecepientBalance(_ balance: AssetBalance)
    func didReceiveFee(result: Result<BigUInt, Error>)
    func didReceiveSendingAssetPrice(_ price: PriceData?)
    func didReceiveUtilityAssetPrice(_ price: PriceData?)
    func didReceiveUtilityAssetMinBalance(_ value: BigUInt)
    func didReceiveSendingAssetExistence(_ value: AssetBalanceExistence)
    func didCompleteSetup()
    func didReceiveError(_ error: Error)
}

protocol OnChainTransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    TransferErrorPresentable, PhishingErrorPresentable, FeeRetryable {
    func showConfirmation(
        from view: TransferSetupChildViewProtocol?,
        chainAsset: ChainAsset,
        sendingAmount: Decimal,
        recepient: AccountAddress
    )
}
