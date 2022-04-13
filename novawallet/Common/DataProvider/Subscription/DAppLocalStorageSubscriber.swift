import Foundation
import RobinHood

protocol DAppLocalStorageSubscriber: AnyObject {
    var dappsLocalSubscriptionFactory: DAppLocalSubscriptionFactoryProtocol { get }

    var dappsLocalSubscriptionHandler: DAppLocalSubscriptionHandler { get }

    func subscribeToFavoriteDApps(
        _ identifier: String?
    ) -> StreamableProvider<DAppFavorite>
}

extension DAppLocalStorageSubscriber {
    func subscribeToFavoriteDApps(
        _ identifier: String?
    ) -> StreamableProvider<DAppFavorite> {
        let provider = dappsLocalSubscriptionFactory.getFavoritesProvider(identifier)

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
}

extension DAppLocalStorageSubscriber where Self: DAppLocalSubscriptionHandler {
    var dappsLocalSubscriptionHandler: DAppLocalSubscriptionHandler { self }
}
