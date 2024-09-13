import Foundation
import Operation_iOS

protocol VotingBasketLocalSubscriptionFactoryProtocol {
    func getVotingBasketItemsProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingBasketItemLocal>
}

class VotingBasketLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory, VotingBasketLocalSubscriptionFactoryProtocol {
    func getVotingBasketItemsProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingBasketItemLocal> {
        let cacheKey = [metaId, chainId].joined(with: .dash)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<VotingBasketItemLocal> {
            return provider
        }

        let source = EmptyStreamableSource<VotingBasketItemLocal>()

        let mapper = VotingBasketItemMapper()
        let filter = NSPredicate.votingBasketItems(
            for: chainId,
            metaId: metaId
        )
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(mapper),
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
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        saveProvider(provider, for: cacheKey)

        return provider
    }
}
