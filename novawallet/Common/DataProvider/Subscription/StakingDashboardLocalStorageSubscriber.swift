import Foundation
import RobinHood

protocol StakingDashboardLocalStorageSubscriber: AnyObject, LocalStorageProviderObserving {
    var stakingDashboardProviderFactory: StakingDashboardProviderFactoryProtocol { get }

    var stakingDashboardLocalStorageHandler: StakingDashboardLocalStorageHandler { get }

    func subscribeDashboardItems(
        for walletId: MetaAccountModel.Id
    ) -> StreamableProvider<Multistaking.DashboardItem>?

    func subscribeDashboardItems(
        for walletId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
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

    func subscribeDashboardItems(
        for walletId: MetaAccountModel.Id,
        chainAssetId: ChainAssetId
    ) -> StreamableProvider<Multistaking.DashboardItem>? {
        guard
            let provider = stakingDashboardProviderFactory.getDashboardItemsProvider(
                for: walletId,
                chainAssetId: chainAssetId
            ) else {
            return nil
        }

        addStreamableProviderObserver(
            for: provider,
            updateClosure: { [weak self] changes in
                self?.stakingDashboardLocalStorageHandler.handleDashboardItems(
                    .success(changes),
                    walletId: walletId,
                    chainAssetId: chainAssetId
                )
            },
            failureClosure: { [weak self] error in
                self?.stakingDashboardLocalStorageHandler.handleDashboardItems(
                    .failure(error),
                    walletId: walletId,
                    chainAssetId: chainAssetId
                )
            }
        )

        return provider
    }
}
