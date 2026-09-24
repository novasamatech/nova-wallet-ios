import Foundation
import Operation_iOS

enum AssetVisibilityRepositoryFactory {
    static func createVisibilityRepository(
        for metaId: MetaAccountModel.Id,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<AssetVisibilityLocal> {
        createVisibilityRepository(
            filter: NSPredicate.assetVisibility(metaId: metaId),
            using: storage
        )
    }

    static func createVisibilityRepository(
        for metaIds: Set<MetaAccountModel.Id>,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<AssetVisibilityLocal> {
        createVisibilityRepository(
            filter: NSPredicate.assetVisibility(metaIds: metaIds),
            using: storage
        )
    }

    static func createVisibilityRepository(
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<AssetVisibilityLocal> {
        createVisibilityRepository(filter: nil, using: storage)
    }

    static func createSettingsRepository(
        for metaId: MetaAccountModel.Id,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<MetaAccountSettingsLocal> {
        createSettingsRepository(
            filter: NSPredicate.metaAccountSettings(metaId: metaId),
            using: storage
        )
    }

    static func createSettingsRepository(
        for metaIds: Set<MetaAccountModel.Id>,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<MetaAccountSettingsLocal> {
        createSettingsRepository(
            filter: NSPredicate.metaAccountSettings(metaIds: metaIds),
            using: storage
        )
    }

    static func createSettingsRepository(
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<MetaAccountSettingsLocal> {
        createSettingsRepository(filter: nil, using: storage)
    }
}

// MARK: Private

private extension AssetVisibilityRepositoryFactory {
    static func createVisibilityRepository(
        filter: NSPredicate?,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<AssetVisibilityLocal> {
        let repository: CoreDataRepository<AssetVisibilityLocal, CDAssetVisibility> = storage.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(AssetVisibilityMapper())
        )

        return AnyDataProviderRepository(repository)
    }

    static func createSettingsRepository(
        filter: NSPredicate?,
        using storage: StorageFacadeProtocol
    ) -> AnyDataProviderRepository<MetaAccountSettingsLocal> {
        let repository: CoreDataRepository<MetaAccountSettingsLocal, CDMetaAccountSettings> = storage.createRepository(
            filter: filter,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(MetaAccountSettingsMapper())
        )

        return AnyDataProviderRepository(repository)
    }
}
