import Operation_iOS

protocol StakingDashboardViewProtocol: ControllerBackedProtocol {
    func didReceiveStakings(viewModel: StakingDashboardViewModel)
    func didReceiveUpdate(viewModel: StakingDashboardUpdateViewModel)
}

protocol StakingDashboardPresenterProtocol: AnyObject {
    func setup()
    func selectActiveStaking(at index: Int)
    func selectInactiveStaking(at index: Int)
    func selectMoreOptions()
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
    func didReceive(walletId: String)
    func didReceive(result: StakingDashboardBuilderResult)
    func didReceive(error: StakingDashboardInteractorError)
}

protocol StakingDashboardWireframeProtocol: ErrorPresentable, AlertPresentable, CommonRetryable {
    func showMoreOptions(from view: ControllerBackedProtocol?)
    func showStakingDetails(
        from view: StakingDashboardViewProtocol?,
        option: Multistaking.ChainAssetOption
    )

    func showStartStaking(from view: StakingDashboardViewProtocol?, chainAsset: ChainAsset)
}
