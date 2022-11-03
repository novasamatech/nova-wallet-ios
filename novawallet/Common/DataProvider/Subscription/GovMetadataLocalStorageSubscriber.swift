import Foundation
import RobinHood

protocol GovMetadataLocalStorageSubscriber: AnyObject {
    var govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol { get }

    var govMetadataLocalSubscriptionHandler: GovMetadataLocalStorageHandler { get }

    func subscribeGovMetadata(for chain: ChainModel) -> AnySingleValueProvider<ReferendumMetadataMapping>
}

extension GovMetadataLocalStorageSubscriber {
    func subscribeGovMetadata(for chain: ChainModel) -> AnySingleValueProvider<ReferendumMetadataMapping> {
        let provider = govMetadataLocalSubscriptionFactory.getMetadataProvider(for: chain)

        let updateClosure: ([DataProviderChange<ReferendumMetadataMapping>]) -> Void = { [weak self] changes in
            let result = changes.reduceToLastChange()
            self?.govMetadataLocalSubscriptionHandler.handleGovMetadata(
                result: .success(result),
                chain: chain
            )
            return
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.govMetadataLocalSubscriptionHandler.handleGovMetadata(result: .failure(error), chain: chain)
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

extension GovMetadataLocalStorageSubscriber where Self: GovMetadataLocalStorageHandler {
    var govMetadataLocalSubscriptionHandler: GovMetadataLocalStorageHandler { self }
}
