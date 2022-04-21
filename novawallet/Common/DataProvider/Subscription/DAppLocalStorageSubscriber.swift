import Foundation
import RobinHood

protocol DAppLocalStorageSubscriber: AnyObject {
    var dAppsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol { get }

    var dappsLocalSubscriptionHandler: DAppLocalSubscriptionHandler { get }

    func subscribeToFavoriteDApps(
        _ identifier: String?
    ) -> StreamableProvider<DAppFavorite>

    func subscribeToAuthorizedDApps(by metaId: String) -> StreamableProvider<DAppSettings>
}

extension DAppLocalStorageSubscriber {
    func subscribeToFavoriteDApps(
        _ identifier: String?
    ) -> StreamableProvider<DAppFavorite> {
        let provider = dAppsLocalSubscriptionFactory.getFavoritesProvider(identifier)

        let updateClosure = {
            [weak self] (changes: [DataProviderChange<DAppFavorite>]) in
            self?.dappsLocalSubscriptionHandler.handleFavoriteDApps(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.dappsLocalSubscriptionHandler.handleFavoriteDApps(result: .failure(error))
            return
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

    func subscribeToAuthorizedDApps(by metaId: String) -> StreamableProvider<DAppSettings> {
        let provider = dAppsLocalSubscriptionFactory.getAuthorizedProvider(for: metaId)

        let updateClosure = {
            [weak self] (changes: [DataProviderChange<DAppSettings>]) in
            self?.dappsLocalSubscriptionHandler.handleAuthorizedDApps(result: .success(changes), for: metaId)
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.dappsLocalSubscriptionHandler.handleAuthorizedDApps(result: .failure(error), for: metaId)
            return
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

extension DAppLocalStorageSubscriber where Self: DAppLocalSubscriptionHandler {
    var dappsLocalSubscriptionHandler: DAppLocalSubscriptionHandler { self }
}
