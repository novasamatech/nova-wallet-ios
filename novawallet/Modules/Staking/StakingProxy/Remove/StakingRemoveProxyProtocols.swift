protocol StakingRemoveProxyInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func remakeSubscriptions()
    func submit()
}

protocol StakingRemoveProxyInteractorOutputProtocol: AnyObject {
    func didReceive(error: StakingRemoveProxyError)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(fee: ExtrinsicFeeProtocol?)
    func didReceive(price: PriceData?)
    func didSubmit(model: ExtrinsicSubmittedModel)
}

enum StakingRemoveProxyError: Error {
    case balance(Error)
    case price(Error)
    case fee(Error)
    case submit(Error)
}
