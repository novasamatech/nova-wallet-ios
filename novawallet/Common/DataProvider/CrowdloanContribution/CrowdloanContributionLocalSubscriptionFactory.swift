import Foundation
import Operation_iOS

protocol CrowdloanContributionSubscriptionMaking {
    func getContributionProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<CrowdloanContribution>
}

final class CrowdloanContributionSubscription: SubstrateLocalSubscriptionFactory {}

extension CrowdloanContributionSubscription: CrowdloanContributionSubscriptionMaking {
    func getContributionProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<CrowdloanContribution> {
        let cacheKey = [
            "crowdloan",
            accountId.toHex(),
            chainAsset.chainAssetId.stringValue
        ].joined(with: .dash)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<CrowdloanContribution> {
            return provider
        }

        let filter = NSPredicate.crowdloanContribution(
            for: chainAsset.chain.chainId,
            accountId: accountId
        )

        let mapper = CrowdloanContributionDataMapper()
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
            predicate: { entity in
                accountId.toHex() == entity.chainAccountId &&
                    chainAsset.chain.chainId == entity.chainId &&
                    chainAsset.asset.assetId == entity.assetId &&
                    entity.type == ExternalAssetBalance.BalanceType.crowdloan.rawValue
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource()),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
