protocol StakingMoreOptionsViewProtocol: ControllerBackedProtocol {
    func didReceive(dAppModels: [ReferendumDAppView.Model])
}

protocol StakingMoreOptionsPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingMoreOptionsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingMoreOptionsInteractorOutputProtocol: AnyObject {
    func didReceive(dAppsResult: Result<DAppList, Error>?)
}

protocol StakingMoreOptionsWireframeProtocol: AnyObject {}
