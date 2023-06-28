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
}

protocol StartStakingInfoInteractorOutputProtocol: AnyObject {
    func didReceiveChainAsset(_ chainAsset: ChainAsset)
    func didReceiveAccount(_ account: MetaChainAccountResponse?)
    func didReceivePrice(_ price: PriceData?)
    func didReceiveAssetBalance(_ assetBalance: AssetBalance?)
    func didReceiveError(_ error: StartStakingInfoError)
    func didReceiveMinStake(_ minStake: BigUInt?)
    func didReceiveEraTime(_ time: TimeInterval?)
}

protocol StartStakingInfoWireframeProtocol: AnyObject {}

enum StartStakingInfoError: Error {
    case assetBalance(Error)
    case price(Error)
    case networkStakingInfo(Error)
    case minStake(Error)
    case createState(Error)
    case stakeTime(Error)
}
