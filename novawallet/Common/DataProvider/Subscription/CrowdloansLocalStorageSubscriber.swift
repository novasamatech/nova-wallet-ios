import Foundation
import RobinHood

protocol CrowdloanContributionLocalSubscriptionHandler: AnyObject {
    func handleCrowdloans(
        result: Result<[DataProviderChange<CrowdloanContributionData>], Error>,
        account: AccountId,
        chain: ChainModel
    )
}

extension CrowdloanContributionLocalSubscriptionHandler {
    func handleCrowdloans(
        result _: Result<[DataProviderChange<CrowdloanContributionData>], Error>,
        account _: AccountId,
        chain _: ChainModel
    ) {}
}

protocol CrowdloansLocalStorageSubscriber: AnyObject {
    var crowdloansLocalSubscriptionFactory: CrowdloanContributionLocalSubscriptionFactoryProtocol { get }

    var crowdloansLocalSubscriptionHandler: CrowdloanContributionLocalSubscriptionHandler { get }

    func subscribeToCrowdloansProvider(
        for account: AccountId,
        chain: ChainModel
    ) -> StreamableProvider<CrowdloanContributionData>?
}

extension CrowdloansLocalStorageSubscriber {
    func subscribeToCrowdloansProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) -> StreamableProvider<CrowdloanContributionData>? {
        guard let provider = crowdloansLocalSubscriptionFactory.getCrowdloanContributionDataProvider(
            for: accountId,
            chain: chain
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<CrowdloanContributionData>]) in
            self?.crowdloansLocalSubscriptionHandler.handleCrowdloans(result: .success(changes), account: accountId, chain: chain)
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.crowdloansLocalSubscriptionHandler.handleCrowdloans(result: .failure(error), account: accountId, chain: chain)
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
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

extension CrowdloansLocalStorageSubscriber where Self: CrowdloanContributionLocalSubscriptionHandler {
    var crowdloansLocalSubscriptionHandler: CrowdloanContributionLocalSubscriptionHandler { self }
}
