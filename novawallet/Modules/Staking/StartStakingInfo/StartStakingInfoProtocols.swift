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
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance)
    func didReceive(baseError: BaseStartStakingInfoError)
    func didReceive(accountId: AccountId?)
}

protocol StartStakingInfoRelaychainInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {
    func retryNetworkStakingInfo()
    func remakeMinNominatorBondSubscription()
    func remakeBagListSizeSubscription()
    func retryEraCompletionTime()
    func remakeCalculator()
}

protocol StartStakingInfoRelaychainInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(minNominatorBond: BigUInt?)
    func didReceive(bagListSize: UInt32?)
    func didReceive(networkInfo: NetworkStakingInfo?)
    func didReceive(eraCountdown: EraCountdown?)
    func didReceive(error: RelaychainStartStakingInfoError)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
}

protocol StartStakingInfoParachainInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {}

protocol StartStakingInfoParachainInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(networkInfo: ParachainStaking.NetworkInfo?)
    func didReceive(error: ParachainStartStakingInfoError)
    func didReceive(parastakingRound: ParachainStaking.RoundInfo?)
    func didReceive(calculator: ParaStakingRewardCalculatorEngineProtocol)
    func didReceive(blockNumber: BlockNumber?)
    func didReceive(stakingDuration: ParachainStakingDuration)
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
    case calculator(Error)
}

enum ParachainStartStakingInfoError: Error {
    case networkInfo(Error)
    case createState(Error)
    case parastakingRound(Error)
    case calculator(Error)
    case blockNumber(Error)
    case stakingDuration(Error)
}
