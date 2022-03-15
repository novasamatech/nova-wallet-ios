import BigInt

protocol TransferSetupViewProtocol: ControllerBackedProtocol {}

protocol TransferSetupPresenterProtocol: AnyObject {
    func setup()
}

protocol TransferSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: BigUInt, recepient: AccountAddress?)
    func change(recepient: AccountAddress?)
}

protocol TransferSetupInteractorOutputProtocol: AnyObject {
    func didReceiveSendingAssetBalance(result: Result<AssetBalance?, Error>)
    func didReceiveUtilityAssetBalance(result: Result<AssetBalance?, Error>)
    func didReceiveFee(result: Result<BigUInt, Error>)
    func didReceiveSendingAssetPrice(result: Result<PriceData?, Error>)
    func didReceiveUtilityAssetPrice(result: Result<PriceData?, Error>)
    func didReceiveSetup(error: Error)
}

protocol TransferSetupWireframeProtocol: AlertPresentable, ErrorPresentable {}
