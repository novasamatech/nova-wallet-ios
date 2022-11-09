import Foundation
import RobinHood

protocol GovMetadataLocalStorageSubscriber: AnyObject {
    var govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol { get }

    var govMetadataLocalSubscriptionHandler: GovMetadataLocalStorageHandler { get }

    func subscribeGovernanceMetadata(
        for chain: ChainModel
    ) -> StreamableProvider<ReferendumMetadataLocal>?

    func subscribeGovernanceMetadata(
        for chain: ChainModel,
        referendumId: ReferendumIdLocal
    ) -> StreamableProvider<ReferendumMetadataLocal>?
}

extension GovMetadataLocalStorageSubscriber {
    func subscribeGovernanceMetadata(
        for chain: ChainModel
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard let provider = govMetadataLocalSubscriptionFactory.getMetadataProvider(for: chain) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<ReferendumMetadataLocal>]) -> Void
        updateClosure = { [weak self] changes in

            let items = changes.mergeToDict([:]).reduce(into: ReferendumMetadataMapping()) {
                $0[$1.value.referendumId] = $1.value
            }

            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataPreview(
                result: .success(items),
                chain: chain
            )
            return
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataPreview(
                result: .failure(error),
                chain: chain
            )
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

    func subscribeGovernanceMetadata(
        for chain: ChainModel,
        referendumId: ReferendumIdLocal
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard
            let provider = govMetadataLocalSubscriptionFactory.getMetadataProvider(
                for: chain,
                referendumId: referendumId
            ) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<ReferendumMetadataLocal>]) -> Void
        updateClosure = { [weak self] changes in
            let item = changes.reduceToLastChange()

            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataDetails(
                result: .success(item),
                chain: chain,
                referendumId: referendumId
            )
            return
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataDetails(
                result: .failure(error),
                chain: chain,
                referendumId: referendumId
            )
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

extension GovMetadataLocalStorageSubscriber where Self: GovMetadataLocalStorageHandler {
    var govMetadataLocalSubscriptionHandler: GovMetadataLocalStorageHandler { self }
}
