import BigInt

protocol StakingProxyBaseInteractorOutputProtocol: AnyObject {
    func didReceive(baseError: StakingProxyBaseError)
    func didReceive(proxyDeposit: ProxyDeposit?)
    func didReceive(assetBalance: AssetBalance?)
    func didReceive(fee: ExtrinsicFeeProtocol?)
    func didReceive(maxProxies: Int?)
    func didReceive(existensialDeposit: BigUInt?)
    func didReceive(proxy: ProxyDefinition?)
    func didReceive(price: PriceData?)
}

enum StakingProxyBaseError: Error {
    case fetchDepositBase(Error)
    case fetchDepositFactor(Error)
    case handleProxies(Error)
    case balance(Error)
    case price(Error)
    case fee(Error)
    case fetchMaxProxyCount(Error)
    case fetchED(Error)
}

protocol StakingProxyBaseInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
    func refetchConstants()
    func remakeSubscriptions()
}

protocol StakingSetupProxyBaseViewProtocol: ControllerBackedProtocol {
    func didReceiveProxyDeposit(viewModel: LoadableViewModelState<NetworkFeeInfoViewModel>)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
}

protocol StakingSetupProxyBasePresenterProtocol: AnyObject {
    func setup()
    func showDepositInfo()
}

protocol StakingSetupProxyBaseWireframeProtocol: ShortTextInfoPresentable, AlertPresentable,
    ErrorPresentable, CommonRetryable {}
