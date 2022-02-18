import Foundation
import RobinHood

protocol NftLocalSubscriptionFactoryProtocol {
    func getNftProvider(for wallet: MetaAccountModel) -> StreamableProvider<NftModel>
}

final class NftLocalSubscriptionFactory: SubstrateLocalSubscriptionFactory,
                                         NftLocalSubscriptionFactoryProtocol {
    func getNftProvider(for wallet: MetaAccountModel) -> StreamableProvider<NftModel> {
        let identifier = ownerId.toHex()

        if let provider = getProvider(for: identifier) as? StreamableProvider<NftModel> {
            return provider
        }

        let mapper = AnyCoreDataMapper(NftModelMapper())
        let repository = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: mapper
        )

        let statemineService = UniquesSyncService(
            chainRegistry: chainRegistry,
            ownerId: ownerId,
            chainId: "",
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue()
        )

        let dataSource = NftStreamableSource(syncServices: [statemineService])

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: mapper,
            predicate: { entity in
                return true
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger.error("Did receive error: \(error)")
            }
        }

        let provider = StreamableProvider(
            source: AnyStreamableSource(dataSource),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: operationManager
        )

        return provider
    }
}
