import Foundation
import Operation_iOS

protocol StakingRewardsLocalSubscriptionFactoryProtocol {
    func getTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: LocalChainExternalApi,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem>
}

final class StakingRewardsLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    StakingRewardsLocalSubscriptionFactoryProtocol {
    func getTotalReward(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        api: LocalChainExternalApi,
        assetPrecision: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        clearIfNeeded()

        let timeIdentifier = [
            startTimestamp.map { "\($0)" } ?? "nil",
            endTimestamp.map { "\($0)" } ?? "nil"
        ].joined(separator: "-")

        let identifier = ("reward" + api.url.absoluteString) + address + timeIdentifier

        if let provider = getProvider(for: identifier) as? SingleValueProvider<TotalRewardItem> {
            return AnySingleValueProvider(provider)
        }

        let repository = SubstrateRepositoryFactory(
            storageFacade: storageFacade
        ).createSingleValueRepository()

        let operationFactory = SubqueryRewardOperationFactory(url: api.url)

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
