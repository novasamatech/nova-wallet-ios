import Foundation
import Operation_iOS

protocol CrowdloanLocalStorageSubscriber: AnyObject {
    var crowdloanSubscriptionFactory: CrowdloanLocalSubscriptionMaking { get }
    var crowdloanSubscriptionHandler: CrowdloanLocalStorageHandler { get }

    func subscribeCrowdloansProvider(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> StreamableProvider<CrowdloanContribution>?
}

extension CrowdloanLocalStorageSubscriber {
    func subscribeCrowdloansProvider(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> StreamableProvider<CrowdloanContribution>? {
        guard
            let provider = crowdloanSubscriptionFactory.getContributionProvider(
                for: accountId,
                chainAssetId: chainAssetId
            ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<CrowdloanContribution>]) in
            self?.crowdloanSubscriptionHandler.handleCrowdloans(
                result: .success(changes),
                accountId: accountId,
                chainAssetId: chainAssetId
            )
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.crowdloanSubscriptionHandler.handleCrowdloans(
                result: .failure(error),
                accountId: accountId,
                chainAssetId: chainAssetId
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
}

extension CrowdloanLocalStorageSubscriber where Self: CrowdloanLocalStorageHandler {
    var crowdloanSubscriptionHandler: CrowdloanLocalStorageHandler { self }
}
