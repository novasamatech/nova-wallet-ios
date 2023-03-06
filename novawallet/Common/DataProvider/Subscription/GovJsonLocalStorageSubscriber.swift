import Foundation
import RobinHood

protocol GovJsonLocalStorageSubscriber: AnyObject {
    var govJsonProviderFactory: JsonDataProviderFactoryProtocol { get }

    var govJsonSubscriptionHandler: GovJsonLocalStorageHandler { get }

    func subscribeDelegatesMetadata(
        for chain: ChainModel
    ) -> AnySingleValueProvider<[GovernanceDelegateMetadataRemote]>
}

extension GovJsonLocalStorageSubscriber {
    func subscribeDelegatesMetadata(
        for chain: ChainModel
    ) -> AnySingleValueProvider<[GovernanceDelegateMetadataRemote]> {
        let metadataUrl = GovernanceDelegateMetadataFactory().createUrl(for: chain)
        let provider: AnySingleValueProvider<[GovernanceDelegateMetadataRemote]> = govJsonProviderFactory.getJson(
            for: metadataUrl
        )

        addDataProviderObserver(
            for: provider,
            updateClosure: { [weak self] value in
                self?.govJsonSubscriptionHandler.handleDelegatesMetadata(
                    result: .success(value ?? []),
                    chain: chain
                )
            },
            failureClosure: { [weak self] error in
                self?.govJsonSubscriptionHandler.handleDelegatesMetadata(
                    result: .failure(error),
                    chain: chain
                )
            }
        )

        return provider
    }

    private func addDataProviderObserver<T: Decodable>(
        for provider: AnySingleValueProvider<T>,
        updateClosure: @escaping (T?) -> Void,
        failureClosure: @escaping (Error) -> Void,
        options: DataProviderObserverOptions = .init(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)
    ) {
        let update = { (changes: [DataProviderChange<T>]) in
            let value = changes.reduceToLastChange()
            updateClosure(value)
        }

        let failure = { error in
            failureClosure(error)
        }

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: update,
            failing: failure,
            options: options
        )
    }
}

extension GovJsonLocalStorageSubscriber where Self: GovJsonLocalStorageHandler {
    var govJsonSubscriptionHandler: GovJsonLocalStorageHandler { self }
}
