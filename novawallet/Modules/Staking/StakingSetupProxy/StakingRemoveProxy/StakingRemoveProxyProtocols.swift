protocol StakingRemoveProxyInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func remakeSubscriptions()
}

protocol StakingRemoveProxyInteractorOutputProtocol: AnyObject {
    func didReceive(removingError: StakingRemoveProxyError)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(fee: ExtrinsicFeeProtocol?)
    func didReceive(proxy: ProxyDefinition?)
    func didReceive(price: PriceData?)
    func didSubmit()
}

enum StakingRemoveProxyError: Error {
    case handleProxies(Error)
    case balance(Error)
    case price(Error)
    case fee(Error)
    case submit(Error)
}
