import BigInt

protocol StakingProxyBaseInteractorOutputProtocol: AnyObject {
    func didReceive(baseError: StakingProxyBaseError)
    func didReceive(proxyDeposit: BigUInt?)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(fee: ExtrinsicFeeProtocol?)
    func didReceive(price: PriceData?)
    func didReceiveAccount(_ account: MetaChainAccountResponse?, for accountId: AccountId)
}

enum StakingProxyBaseError: Error {
    case fetchDepositBase(Error)
    case fetchDepositFactor(Error)
    case handleProxies(Error)
    case balance(Error)
    case price(Error)
    case stashItem(Error)
    case fee(Error)
}

protocol StakingProxyBaseInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}
