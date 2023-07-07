import BigInt

protocol StartStakingInfoViewProtocol: AnyObject, ControllerBackedProtocol {
    func didReceive(viewModel: LoadableViewModelState<StartStakingViewModel>)
    func didReceive(balance: String)
}

protocol StartStakingInfoPresenterProtocol: AnyObject {
    func setup()
}

protocol StartStakingInfoInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
}

protocol StartStakingInfoInteractorOutputProtocol: AnyObject {
    func didReceive(chainAsset: ChainAsset)
    func didReceive(account: MetaChainAccountResponse?)
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance)
    func didReceive(baseError: BaseStartStakingInfoError)
}

protocol StartStakingInfoRelaychainInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {
    func retryNetworkStakingInfo()
    func remakeMinNominatorBondSubscription()
    func remakeBagListSizeSubscription()
    func retryEraCompletionTime()
}

protocol StartStakingInfoRelaychainInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(minNominatorBond: BigUInt?)
    func didReceive(bagListSize: UInt32?)
    func didReceive(networkInfo: NetworkStakingInfo?)
    func didReceive(eraCountdown: EraCountdown?)
    func didReceive(error: RelaychainStartStakingInfoError)
}

protocol StartStakingInfoWireframeProtocol: CommonRetryable, AlertPresentable {}

enum BaseStartStakingInfoError: Error {
    case assetBalance(Error?)
    case price(Error)
}

enum RelaychainStartStakingInfoError: Error {
    case networkStakingInfo(Error)
    case createState(Error)
    case eraCountdown(Error)
    case bagListSize(Error)
    case minNominatorBond(Error)
}
