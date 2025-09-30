import Foundation
import Operation_iOS

protocol StakingRewardsLocalSubscriptionFactoryProtocol {
    func getTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem>
}

final class StakingRewardsLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    StakingRewardsLocalSubscriptionFactoryProtocol {
    func getTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: Set<LocalChainExternalApi>,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        clearIfNeeded()

        let timeIdentifier = [
            startTimestamp.map { "\($0)" } ?? "nil",
            endTimestamp.map { "\($0)" } ?? "nil"
        ].joined(with: .dash)

        let identifier = ("reward" + api.map(\.url.absoluteString).joined(with: .dash))
            + address
            + timeIdentifier

        if let provider = getProvider(for: identifier) as? SingleValueProvider<TotalRewardItem> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createSingleValueRepository()

        let operationFactory = SubqueryRewardAggregatingWrapperFactory(
            factories: api.map { SubqueryRewardOperationFactory(url: $0.url) }
        )

        let source = SubqueryTotalRewardSource(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            assetPrecision: assetPrecision,
            operationFactory: operationFactory,
            stakingType: .direct
        )

        let anySource = AnySingleValueProviderSource<TotalRewardItem>(source)

        let provider = SingleValueProvider(
            targetIdentifier: identifier,
            source: anySource,
            repository: AnyDataProviderRepository(repository)
        )

        saveProvider(provider, for: identifier)

        return AnySingleValueProvider(provider)
    }
}
