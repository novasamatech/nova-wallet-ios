import Foundation
import Operation_iOS

final class RemovedWalletDAppSettingsCleaner {
    private let authorizedDAppRepository: AnyDataProviderRepository<DAppSettings>

    init(authorizedDAppRepository: AnyDataProviderRepository<DAppSettings>) {
        self.authorizedDAppRepository = authorizedDAppRepository
    }
}

// MARK: WalletStorageCleaning

extension RemovedWalletDAppSettingsCleaner: WalletStorageCleaning {
    func cleanStorage(
        using providers: WalletStorageCleaningProviders
    ) -> CompoundOperationWrapper<Void> {
        let fetchOptions = RepositoryFetchOptions()
        let fetchSettingsOperation = authorizedDAppRepository.fetchAllOperation(with: fetchOptions)

        let deletionBlock: () throws -> [String] = {
            let removedWalletsIds = Set(
                try providers.changesProvider()
                    .filter { $0.isDeletion }
                    .map(\.identifier)
            )
            let dappSettingsIds = try fetchSettingsOperation.extractNoCancellableResultData()
                .filter { removedWalletsIds.contains($0.metaId) }
                .map(\.identifier)

            return dappSettingsIds
        }

        let removeSettingsOperation = authorizedDAppRepository.saveOperation(
            { [] },
            deletionBlock
        )

        removeSettingsOperation.addDependency(fetchSettingsOperation)

        return CompoundOperationWrapper(
            targetOperation: removeSettingsOperation,
            dependencies: [fetchSettingsOperation]
        )
    }
}
