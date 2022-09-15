import Foundation
import RobinHood

protocol ParaStkYieldBoostStorageSubscriber where Self: AnyObject {
    var yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol { get }

    var yieldBoostSubscriptionHandler: ParaStkYieldBoostSubscriptionHandler { get }

    func subscribeYieldBoostTasks(
        for chainAssetId: ChainAssetId,
        accountId: AccountId
    ) -> AnySingleValueProvider<[ParaStkYieldBoostState.Task]>?
}

extension ParaStkYieldBoostStorageSubscriber {
    func subscribeYieldBoostTasks(
        for chainAssetId: ChainAssetId,
        accountId: AccountId
    ) -> AnySingleValueProvider<[ParaStkYieldBoostState.Task]>? {
        guard
            let provider = try? yieldBoostProviderFactory.getTasksProvider(
                for: chainAssetId,
                accountId: accountId
            ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<[ParaStkYieldBoostState.Task]>]) in
            let finalValue = changes.reduceToLastChange()
            self?.yieldBoostSubscriptionHandler.handleYieldBoostTasks(
                result: .success(finalValue),
                chainId: chainAssetId.chainId,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.yieldBoostSubscriptionHandler.handleYieldBoostTasks(
                result: .failure(error),
                chainId: chainAssetId.chainId,
                accountId: accountId
            )
            return
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)

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

extension ParaStkYieldBoostStorageSubscriber where Self: ParaStkYieldBoostSubscriptionHandler {
    var yieldBoostSubscriptionHandler: ParaStkYieldBoostSubscriptionHandler { self }
}
