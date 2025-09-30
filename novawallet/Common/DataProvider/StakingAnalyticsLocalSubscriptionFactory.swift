import Foundation
import Operation_iOS

protocol StakingAnalyticsLocalSubscriptionFactoryProtocol {
    func getWeaklyAnalyticsProvider(
        for address: AccountAddress,
        urls: [URL]
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]>
}

final class StakingAnalyticsLocalSubscriptionFactory {
    private var providers: [String: WeakWrapper] = [:]

    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func saveProvider(_ provider: AnyObject, for key: String) {
        providers[key] = WeakWrapper(target: provider)
    }

    func getProvider(for key: String) -> AnyObject? { providers[key]?.target }

    func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

private extension StakingAnalyticsLocalSubscriptionFactory {
    func createHash(
        for address: AccountAddress,
        urls: [URL]
    ) -> Int {
        var hasher = Hasher()

        hasher.combine(address)

        urls
            .map(\.absoluteString)
            .sorted()
            .forEach { hasher.combine($0) }

        return hasher.finalize()
    }
}

extension StakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol {
    func getWeaklyAnalyticsProvider(
        for address: AccountAddress,
        urls: [URL]
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]> {
        clearIfNeeded()

        let hash = createHash(for: address, urls: urls)
        let identifier = "weaklyAnalytics_\(hash)"

        if let provider = getProvider(for: identifier) as? SingleValueProvider<[SubqueryRewardItemData]> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(storageFacade: storageFacade)
            .createSingleValueRepository()

        let operationFactory = SubqueryRewardAggregatingWrapperFactory(
            factories: urls.map { SubqueryRewardOperationFactory(url: $0) }
        )
        let source = WeaklyAnalyticsRewardSource(
            address: address,
            operationFactory: operationFactory
        )

        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: AnySingleValueProviderSource(source),
            repository: repository
        )

        saveProvider(provider, for: identifier)

        return AnySingleValueProvider(provider)
    }
}
