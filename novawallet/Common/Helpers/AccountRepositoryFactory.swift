import Foundation
import IrohaCrypto
import RobinHood

protocol AccountRepositoryFactoryProtocol {
    func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel>

    func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel>

    func createFavoriteDAppsRepository() -> AnyDataProviderRepository<DAppFavorite>

    func createAuthorizedDAppsRepository(for metaId: String) -> AnyDataProviderRepository<DAppSettings>
}

extension AccountRepositoryFactoryProtocol {
    func createAccountRepository(
        for accountId: AccountId
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        let filter = NSPredicate.filterMetaAccountByAccountId(accountId)
        let sortition = NSSortDescriptor.accountsByOrder

        return createMetaAccountRepository(for: filter, sortDescriptors: [sortition])
    }
}

final class AccountRepositoryFactory: AccountRepositoryFactoryProtocol {
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func createMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        let mapper = MetaAccountMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    func createManagedMetaAccountRepository(
        for filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]
    ) -> AnyDataProviderRepository<ManagedMetaAccountModel> {
        let mapper = ManagedMetaAccountMapper()

        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: sortDescriptors,
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    func createFavoriteDAppsRepository() -> AnyDataProviderRepository<DAppFavorite> {
        let mapper = DAppFavoriteMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    func createAuthorizedDAppsRepository(for metaId: String) -> AnyDataProviderRepository<DAppSettings> {
        let mapper = DAppSettingsMapper()
        let filter = NSPredicate.filterAuthorizedDApps(by: metaId)
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }
}
