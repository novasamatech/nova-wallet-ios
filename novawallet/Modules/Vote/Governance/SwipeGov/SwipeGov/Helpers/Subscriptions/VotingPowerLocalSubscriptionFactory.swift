import Foundation
import Operation_iOS

protocol VotingPowerLocalSubscriptionFactoryProtocol {
    func getVotingPowerProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingPowerLocal>
}

class VotingPowerLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory, 
                                            VotingPowerLocalSubscriptionFactoryProtocol {
    func getVotingPowerProvider(
        for chainId: ChainModel.Id,
        metaId: MetaAccountModel.Id
    ) -> StreamableProvider<VotingPowerLocal> {
        let cacheKey = [metaId, chainId].joined(with: .dash)

        if let provider = getProvider(for: cacheKey) as? StreamableProvider<VotingPowerLocal> {
            return provider
        }

        let source = EmptyStreamableSource<VotingPowerLocal>()

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(VotingPowerMapper()),
            predicate: { entity in
                chainId == entity.chainId && metaId == entity.metaId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let repository = SwipeGovRepositoryFactory.createVotingPowerRepository(
            for: chainId,
            metaId: metaId,
            using: storageFacade
        )

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
