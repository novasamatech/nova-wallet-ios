import RobinHood

protocol StakingDashboardViewProtocol: ControllerBackedProtocol {
    func didReceiveWallet(viewModel: WalletSwitchViewModel)
    func didReceiveStakings(viewModel: StakingDashboardViewModel)
    func didReceiveUpdate(viewModel: StakingDashboardUpdateViewModel)
}

protocol StakingDashboardPresenterProtocol: AnyObject {
    func setup()
    func selectActiveStaking(at index: Int)
    func selectInactiveStaking(at index: Int)
    func selectMoreOptions()
    func switchWallet()
    func refresh()
}

protocol StakingDashboardInteractorInputProtocol: AnyObject {
    func setup()

    func retryBalancesSubscription()
    func retryPricesSubscription()
    func retryDashboardSubscription()

    func refresh()
}

protocol StakingDashboardInteractorOutputProtocol: AnyObject {
    func didReceive(wallet: MetaAccountModel)
    func didReceive(result: StakingDashboardBuilderResult)
    func didReceive(error: StakingDashboardInteractorError)
}

protocol StakingDashboardWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable,
    WalletSwitchPresentable {
    func showMoreOptions(from view: ControllerBackedProtocol?)
    func showStakingDetails(
        from view: StakingDashboardViewProtocol?,
        option: Multistaking.ChainAssetOption
    )
    func showStartStaking(
        from view: StakingDashboardViewProtocol?,
        option: Multistaking.ChainAssetOption
    )
}
