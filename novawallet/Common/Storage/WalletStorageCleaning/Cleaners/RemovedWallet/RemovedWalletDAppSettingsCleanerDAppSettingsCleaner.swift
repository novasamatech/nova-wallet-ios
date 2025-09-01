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
            let removedWallets = try providers.changesProvider()
                .filter { $0.isDeletion }
                .map(\.identifier)
            let dappSettingsIds = try fetchSettingsOperation.extractNoCancellableResultData()
                .compactMap(\.metaId)
                .filter { removedWallets.contains($0) }

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
