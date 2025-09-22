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
        let removedWalletsIds = Set(
            providers.changesProvider()
                .filter { $0.isDeletion }
                .map(\.identifier)
        )

        guard !removedWalletsIds.isEmpty else {
            return .createWithResult(())
        }

        let fetchOptions = RepositoryFetchOptions()
        let fetchSettingsOperation = authorizedDAppRepository.fetchAllOperation(with: fetchOptions)

        let deletionBlock: () throws -> [String] = {
            let dappSettingsIds = try fetchSettingsOperation.extractNoCancellableResultData()
                .filter {
                    guard let metaId = $0.metaId else { return true }

                    return removedWalletsIds.contains(metaId)
                }
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
