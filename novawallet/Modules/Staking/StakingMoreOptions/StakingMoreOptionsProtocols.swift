protocol StakingMoreOptionsViewProtocol: ControllerBackedProtocol {
    func didReceive(dAppModels: [DAppView.Model])
    func didReceive(moreOptionsModels: [StakingDashboardDisabledViewModel])
}

protocol StakingMoreOptionsPresenterProtocol: AnyObject {
    func setup()
    func selectDApp(at index: Int)
    func selectOption(at index: Int)
}

protocol StakingMoreOptionsInteractorInputProtocol: AnyObject {
    func setup()
    func remakeDAppsSubscription()
}

protocol StakingMoreOptionsInteractorOutputProtocol: AnyObject {
    func didReceive(dAppsResult: Result<DAppList, Error>?)
    func didReceive(moreOptions: [StakingDashboardItemModel])
}

protocol StakingMoreOptionsWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable {
    func showBrowser(from view: ControllerBackedProtocol?, for dApp: DApp)
}
