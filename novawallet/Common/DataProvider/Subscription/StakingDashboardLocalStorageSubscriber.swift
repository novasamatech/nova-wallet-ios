import Foundation
import RobinHood

protocol StakingDashboardLocalStorageSubscriber: AnyObject {
    var stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol { get }

    var stakingDashboardLocalStorageHandler: StakingDashboardLocalStorageHandler { get }

    func subscribeDashboardItems(
        for walletId: MetaAccountModel.Id
    ) -> StreamableProvider<Multistaking.DashboardItem>?
}

extension StakingDashboardLocalStorageSubscriber where Self: StakingDashboardLocalStorageHandler {
    var stakingDashboardLocalStorageHandler: StakingDashboardLocalStorageHandler { self }

    func subscribeDashboardItems(
        for walletId: MetaAccountModel.Id
    ) -> StreamableProvider<Multistaking.DashboardItem>? {
        guard let provider = stakingDashboardProviderFactory.getDashboardItemsProvider(for: walletId) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<Multistaking.DashboardItem>]) -> Void = { [weak self] changes in
            self?.stakingDashboardLocalStorageHandler.handleDashboardItems(
                .success(changes),
                walletId: walletId
            )
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.stakingDashboardLocalStorageHandler.handleDashboardItems(
                .failure(error),
                walletId: walletId
            )
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
        )

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}
