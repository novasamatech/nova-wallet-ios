import Foundation
import Operation_iOS

protocol RuntimeMetadataRepositoryFactoryProtocol {
    func createRepository() -> AnyDataProviderRepository<RuntimeMetadataItem>
    func createRepository(for chainId: ChainModel.Id) -> AnyDataProviderRepository<RuntimeMetadataItem>
}

final class RuntimeMetadataRepositoryFactory {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }
}

extension RuntimeMetadataRepositoryFactory: RuntimeMetadataRepositoryFactoryProtocol {
    func createRepository() -> AnyDataProviderRepository<RuntimeMetadataItem> {
        let repository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem>

        let mapper = RuntimeMetadataItemMapper()
        repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    func createRepository(for chainId: ChainModel.Id) -> AnyDataProviderRepository<RuntimeMetadataItem> {
        let mapper = RuntimeMetadataItemMapper()
        let repository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> = storageFacade.createRepository(
            filter: NSPredicate.filterRuntimeMetadataItemsBy(identifier: chainId),
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
