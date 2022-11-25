import Foundation
import RobinHood

protocol GovMetadataLocalStorageSubscriber: AnyObject {
    var govMetadataLocalSubscriptionFactory: GovMetadataLocalSubscriptionFactoryProtocol { get }

    var govMetadataLocalSubscriptionHandler: GovMetadataLocalStorageHandler { get }

    func subscribeGovernanceMetadata(
        for option: GovernanceSelectedOption
    ) -> StreamableProvider<ReferendumMetadataLocal>?

    func subscribeGovernanceMetadata(
        for option: GovernanceSelectedOption,
        referendumId: ReferendumIdLocal
    ) -> StreamableProvider<ReferendumMetadataLocal>?
}

extension GovMetadataLocalStorageSubscriber {
    func subscribeGovernanceMetadata(
        for option: GovernanceSelectedOption
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard let provider = govMetadataLocalSubscriptionFactory.getMetadataProvider(for: option) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<ReferendumMetadataLocal>]) -> Void
        updateClosure = { [weak self] changes in
            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataPreview(
                result: .success(changes),
                option: option
            )
            return
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataPreview(
                result: .failure(error),
                option: option
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
        for option: GovernanceSelectedOption,
        referendumId: ReferendumIdLocal
    ) -> StreamableProvider<ReferendumMetadataLocal>? {
        guard
            let provider = govMetadataLocalSubscriptionFactory.getMetadataProvider(
                for: option,
                referendumId: referendumId
            ) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<ReferendumMetadataLocal>]) -> Void
        updateClosure = { [weak self] changes in
            let item = changes.reduceToLastChange()

            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataDetails(
                result: .success(item),
                option: option,
                referendumId: referendumId
            )
            return
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.govMetadataLocalSubscriptionHandler.handleGovernanceMetadataDetails(
                result: .failure(error),
                option: option,
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
