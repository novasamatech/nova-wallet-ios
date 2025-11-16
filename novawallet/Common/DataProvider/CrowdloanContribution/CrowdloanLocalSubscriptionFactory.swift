import Foundation
import Operation_iOS

protocol CrowdloanLocalSubscriptionMaking {
    func getContributionProvider(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> StreamableProvider<CrowdloanContribution>?
}

final class CrowdloanLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory {}

extension CrowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionMaking {
    func getContributionProvider(
        for accountId: AccountId,
        chainAssetId: ChainAssetId
    ) -> StreamableProvider<CrowdloanContribution>? {
        let cacheKey = [
            "crowdloan",
            accountId.toHex(),
            chainAssetId.stringValue
        ].joined(with: .dash)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<CrowdloanContribution> {
            return provider
        }

        let filter = NSPredicate.crowdloanContribution(
            for: chainAssetId.chainId,
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
                    chainAssetId.chainId == entity.chainId &&
                    chainAssetId.assetId == entity.assetId &&
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
