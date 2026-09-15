import Foundation
import Operation_iOS

protocol AssetVisibilitySubscriptionHandler {
    func handleAssetVisibility(
        result: Result<[DataProviderChange<AssetVisibilityLocal>], Error>,
        metaId: MetaAccountModel.Id
    )

    func handleMetaAccountSettings(
        result: Result<[DataProviderChange<MetaAccountSettingsLocal>], Error>,
        metaId: MetaAccountModel.Id
    )
}

extension AssetVisibilitySubscriptionHandler {
    func handleAssetVisibility(
        result _: Result<[DataProviderChange<AssetVisibilityLocal>], Error>,
        metaId _: MetaAccountModel.Id
    ) {}

    func handleMetaAccountSettings(
        result _: Result<[DataProviderChange<MetaAccountSettingsLocal>], Error>,
        metaId _: MetaAccountModel.Id
    ) {}
}

protocol AssetVisibilityLocalStorageSubscriber: LocalStorageProviderObserving where Self: AnyObject {
    var assetVisibilitySubscriptionFactory: AssetVisibilityLocalSubscriptionFactoryProtocol { get }
    var assetVisibilitySubscriptionHandler: AssetVisibilitySubscriptionHandler { get }

    func subscribeToAssetVisibilityProvider(
        for metaId: MetaAccountModel.Id
    ) -> StreamableProvider<AssetVisibilityLocal>

    func subscribeToMetaAccountSettingsProvider(
        for metaId: MetaAccountModel.Id
    ) -> StreamableProvider<MetaAccountSettingsLocal>
}

extension AssetVisibilityLocalStorageSubscriber {
    func subscribeToAssetVisibilityProvider(
        for metaId: MetaAccountModel.Id
    ) -> StreamableProvider<AssetVisibilityLocal> {
        let provider = assetVisibilitySubscriptionFactory.getVisibilityProvider(for: metaId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<AssetVisibilityLocal>]) in
            self?.assetVisibilitySubscriptionHandler.handleAssetVisibility(
                result: .success(changes),
                metaId: metaId
            )
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.assetVisibilitySubscriptionHandler.handleAssetVisibility(
                result: .failure(error),
                metaId: metaId
            )
            return
        }

        provider.removeObserver(self)

        addStreamableProviderObserver(
            for: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )

        return provider
    }

    func subscribeToMetaAccountSettingsProvider(
        for metaId: MetaAccountModel.Id
    ) -> StreamableProvider<MetaAccountSettingsLocal> {
        let provider = assetVisibilitySubscriptionFactory.getSettingsProvider(for: metaId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<MetaAccountSettingsLocal>]) in
            self?.assetVisibilitySubscriptionHandler.handleMetaAccountSettings(
                result: .success(changes),
                metaId: metaId
            )
            return
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.assetVisibilitySubscriptionHandler.handleMetaAccountSettings(
                result: .failure(error),
                metaId: metaId
            )
            return
        }

        provider.removeObserver(self)

        addStreamableProviderObserver(
            for: provider,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )

        return provider
    }
}

extension AssetVisibilityLocalStorageSubscriber where Self: AssetVisibilitySubscriptionHandler {
    var assetVisibilitySubscriptionHandler: AssetVisibilitySubscriptionHandler { self }
}
