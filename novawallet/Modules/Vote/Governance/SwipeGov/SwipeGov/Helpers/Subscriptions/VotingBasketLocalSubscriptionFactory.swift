import Foundation
import Operation_iOS

protocol VotingBasketLocalSubscriptionFactoryProtocol {
    func getVotingBasketItemsProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingBasketItemLocal>
}

class VotingBasketLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
    VotingBasketLocalSubscriptionFactoryProtocol {
    func getVotingBasketItemsProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingBasketItemLocal> {
        let cacheKey = [metaId, chainId].joined(with: .dash)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<VotingBasketItemLocal> {
            return provider
        }

        let source = EmptyStreamableSource<VotingBasketItemLocal>()

        let repository = SwipeGovRepositoryFactory.createVotingItemsRepository(
            for: chainId,
            metaId: metaId,
            using: storageFacade
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(VotingBasketItemMapper()),
            predicate: { entity in
                chainId == entity.chainId && metaId == entity.metaId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: repository,
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
