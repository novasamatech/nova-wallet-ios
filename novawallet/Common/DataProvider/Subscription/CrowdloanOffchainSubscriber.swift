import Foundation
import RobinHood

protocol CrowdloanOffchainSubscriber where Self: AnyObject {
    var crowdloanOffchainProviderFactory: CrowdloanOffchainProviderFactoryProtocol { get }

    var crowdloanOffchainSubscriptionHandler: CrowdloanOffchainSubscriptionHandler { get }

    func subscribeToExternalContributionsProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) -> AnySingleValueProvider<[ExternalContribution]>?
}

extension CrowdloanOffchainSubscriber {
    func subscribeToExternalContributionsProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) -> AnySingleValueProvider<[ExternalContribution]>? {
        guard let provider = try? crowdloanOffchainProviderFactory.getExternalContributionProvider(
            for: accountId,
            chain: chain
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<[ExternalContribution]>]) in
            let contributions = changes.reduceToLastChange()
            self?.crowdloanOffchainSubscriptionHandler.handleExternalContributions(
                result: .success(contributions),
                chainId: chain.chainId,
                accountId: accountId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.crowdloanOffchainSubscriptionHandler.handleExternalContributions(
                result: .failure(error),
                chainId: chain.chainId,
                accountId: accountId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
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

extension CrowdloanOffchainSubscriber where Self: CrowdloanOffchainSubscriptionHandler {
    var crowdloanOffchainSubscriptionHandler: CrowdloanOffchainSubscriptionHandler { self }
}
