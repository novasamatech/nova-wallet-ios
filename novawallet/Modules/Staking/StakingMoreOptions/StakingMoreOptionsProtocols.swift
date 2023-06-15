protocol StakingMoreOptionsViewProtocol: AnyObject {}

protocol StakingMoreOptionsPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingMoreOptionsInteractorInputProtocol: AnyObject {}

protocol StakingMoreOptionsInteractorOutputProtocol: AnyObject {
    func didReceive(dAppsResult: Result<DAppList, Error>?)
}

protocol StakingMoreOptionsWireframeProtocol: AnyObject {}
