import Foundation
import Operation_iOS

protocol GiftsLocalSubscriptionFactoryProtocol {
    func getAllGiftsProvider(for metaId: MetaAccountModel.Id?) -> StreamableProvider<GiftModel>
}

extension GiftsLocalSubscriptionFactoryProtocol {
    func getAllGiftsProvider(for _: MetaAccountModel.Id? = nil) -> StreamableProvider<GiftModel> {
        getAllGiftsProvider(for: nil)
    }
}

final class GiftsLocalSubscriptionFactory {
    static let shared = GiftsLocalSubscriptionFactory(
        storageFacade: UserDataStorageFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )

    let storageFacade: StorageFacadeProtocol
    let logger: LoggerProtocol?
    let operationQueue: OperationQueue

    private(set) var providerStore: [String: WeakWrapper] = [:]

    init(
        storageFacade: StorageFacadeProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil
    ) {
        self.storageFacade = storageFacade
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func runStoreCleaner() {
        providerStore = providerStore.filter { $0.value.target != nil }
    }
}

extension GiftsLocalSubscriptionFactory: GiftsLocalSubscriptionFactoryProtocol {
    func getAllGiftsProvider(for metaId: MetaAccountModel.Id?) -> StreamableProvider<GiftModel> {
        runStoreCleaner()

        let key = "all" + (metaId ?? "")

        if let provider = providerStore[key]?.target as? StreamableProvider<GiftModel> {
            return provider
        }

        let repository: CoreDataRepository<GiftModel, CDGift>

        let mapper = GiftMapper()
        if let metaId {
            let filter = NSPredicate.gifts(for: metaId)
            repository = storageFacade.createRepository(
                filter: filter,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )
        } else {
            repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        }

        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: AnyCoreDataMapper(repository.dataMapper),
            predicate: { entity in
                guard let metaId else {
                    return true
                }

                return entity.metaId == metaId
            }
        )

        observable.start { [weak self] error in
            if let error = error {
                self?.logger?.error("Did receive error: \(error)")
            }
        }

        let source = EmptyStreamableSource<GiftModel>()

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        providerStore[key] = WeakWrapper(target: provider)

        return provider
    }
}
