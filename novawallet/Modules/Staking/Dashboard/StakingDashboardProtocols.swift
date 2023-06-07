import RobinHood

protocol StakingDashboardViewProtocol: ControllerBackedProtocol {
    func didReceiveWallet(viewModel: WalletSwitchViewModel)
    func didReceiveStakings(viewModel: StakingDashboardViewModel)
}

protocol StakingDashboardPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingDashboardInteractorInputProtocol: AnyObject {
    func setup()

    func retryBalancesSubscription()
    func retryPricesSubscription()
    func retryDashboardSubscription()
}

protocol StakingDashboardInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceive(model: StakingDashboardModel)
    func didReceive(error: StakingDashboardInteractorError)
}

protocol StakingDashboardWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable {}
