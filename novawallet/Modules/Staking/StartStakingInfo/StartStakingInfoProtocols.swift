import BigInt

protocol StartStakingInfoViewProtocol: AnyObject, ControllerBackedProtocol {
    func didReceive(viewModel: LoadableViewModelState<StartStakingViewModel>)
    func didReceive(balance: String)
}

protocol StartStakingInfoPresenterProtocol: AnyObject {
    func setup()
    func startStaking()
}

protocol StartStakingInfoInteractorInputProtocol: AnyObject {
    func setup()
    func remakeSubscriptions()
}

protocol StartStakingInfoInteractorOutputProtocol: AnyObject {
    func didReceive(price: PriceData?)
    func didReceive(assetBalance: AssetBalance)
    func didReceive(baseError: BaseStartStakingInfoError)
    func didReceive(wallet: MetaAccountModel, chainAccountId: AccountId?)
    func didReceiveStakingEnabled()
}

protocol StartStakingInfoRelaychainInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {
    func retryDirectStakingMinStake()
    func retryEraCompletionTime()
    func retryNominationPoolsMinStake()
    func remakeCalculator()
}

protocol StartStakingInfoRelaychainInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(networkInfo: NetworkStakingInfo)
    func didReceive(directStakingMinStake: BigUInt)
    func didReceive(nominationPoolMinStake: BigUInt?)
    func didReceive(eraCountdown: EraCountdown?)
    func didReceive(error: RelaychainStartStakingInfoError)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
}

protocol StartStakingInfoParachainInteractorInputProtocol: StartStakingInfoInteractorInputProtocol {
    func retryNetworkStakingInfo()
    func remakeCalculator()
    func retryStakingDuration()
    func retryRewardPaymentDelay()
}

protocol StartStakingInfoParachainInteractorOutputProtocol: StartStakingInfoInteractorOutputProtocol {
    func didReceive(networkInfo: ParachainStaking.NetworkInfo?)
    func didReceive(error: ParachainStartStakingInfoError)
    func didReceive(parastakingRound: ParachainStaking.RoundInfo?)
    func didReceive(calculator: CollatorStakingRewardCalculatorEngineProtocol)
    func didReceive(blockNumber: BlockNumber?)
    func didReceive(stakingDuration: ParachainStakingDuration)
    func didReceive(rewardPaymentDelay: UInt32)
}

protocol StartStakingInfoWireframeProtocol: CommonRetryable, AlertPresentable, NoAccountSupportPresentable,
    ErrorPresentable, StakingErrorPresentable {
    func showWalletDetails(from view: ControllerBackedProtocol?, wallet: MetaAccountModel)
    func showSetupAmount(from view: ControllerBackedProtocol?)
    func complete(from view: ControllerBackedProtocol?)
}

enum BaseStartStakingInfoError: Error {
    case assetBalance(Error?)
    case price(Error)
    case stakingState(Error)
}

enum RelaychainStartStakingInfoError: Error {
    case createState(Error)
    case eraCountdown(Error)
    case directStakingMinStake(Error)
    case nominationPoolsMinStake(Error)
    case calculator(Error)
}

enum ParachainStartStakingInfoError: Error {
    case networkInfo(Error)
    case createState(Error)
    case parastakingRound(Error)
    case calculator(Error)
    case blockNumber(Error)
    case stakingDuration(Error)
    case rewardPaymentDelay(Error)
}
