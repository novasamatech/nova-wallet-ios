import Foundation
import RobinHood

protocol ExternalAssetBalanceSubscriber: AnyObject {
    var externalBalancesSubscriptionFactory: ExternalBalanceLocalSubscriptionFactoryProtocol { get }
    var externalBalancesSubscriptionHandler: ExternalAssetBalanceSubscriptionHandler { get }

    func subscribeToExternalAssetBalancesProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ExternalAssetBalance>?

    func subscribeToAllExternalAssetBalancesProvider() -> StreamableProvider<ExternalAssetBalance>?
}

extension ExternalAssetBalanceSubscriber {
    func subscribeToExternalAssetBalancesProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ExternalAssetBalance>? {
        guard
            let provider = externalBalancesSubscriptionFactory.getExternalAssetBalanceProvider(
                for: accountId,
                chainAsset: chainAsset
            ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ExternalAssetBalance>]) in
            self?.externalBalancesSubscriptionHandler.handleExternalAssetBalances(
                result: .success(changes),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.externalBalancesSubscriptionHandler.handleExternalAssetBalances(
                result: .failure(error),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
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

    func subscribeToAllExternalAssetBalancesProvider() -> StreamableProvider<ExternalAssetBalance>? {
        guard let provider = externalBalancesSubscriptionFactory.getAllExternalAssetBalanceProvider() else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ExternalAssetBalance>]) in
            self?.externalBalancesSubscriptionHandler.handleAllExternalAssetBalances(result: .success(changes))
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.externalBalancesSubscriptionHandler.handleAllExternalAssetBalances(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: false
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

extension ExternalAssetBalanceSubscriber where Self: ExternalAssetBalanceSubscriptionHandler {
    var externalBalancesSubscriptionHandler: ExternalAssetBalanceSubscriptionHandler { self }
}
