import Foundation
import NovaCrypto
import Operation_iOS

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

    func createAuthorizedDAppsRepository(for metaId: String?) -> AnyDataProviderRepository<DAppSettings>

    func createDAppsGlobalSettingsRepository() -> AnyDataProviderRepository<DAppGlobalSettings>

    func createDelegatedAccountSettingsRepository() -> AnyDataProviderRepository<DelegatedAccountSettings>
}

extension AccountRepositoryFactoryProtocol {
    func createAccountRepository(
        for accountId: AccountId
    ) -> AnyDataProviderRepository<MetaAccountModel> {
        let filter = NSPredicate.filterMetaAccountByAccountId(accountId)
        let sortings: [NSSortDescriptor] = [
            .accountsBySelection,
            .accountsByOrder
        ]

        return createMetaAccountRepository(for: filter, sortDescriptors: sortings)
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

    func createDAppsGlobalSettingsRepository() -> AnyDataProviderRepository<DAppGlobalSettings> {
        let mapper = DAppGlobalSettingsMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))

        return AnyDataProviderRepository(repository)
    }

    func createAuthorizedDAppsRepository(for metaId: String?) -> AnyDataProviderRepository<DAppSettings> {
        let mapper = DAppSettingsMapper()

        let filter = metaId.map { NSPredicate.filterAuthorizedBrowserDApps(by: $0) }
        let repository = storageFacade.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return AnyDataProviderRepository(repository)
    }

    func createDelegatedAccountSettingsRepository() -> AnyDataProviderRepository<DelegatedAccountSettings> {
        let mapper = DelegatedAccountSettingsMapper()
        let repository = storageFacade.createRepository(mapper: AnyCoreDataMapper(mapper))
        return AnyDataProviderRepository(repository)
    }
}
