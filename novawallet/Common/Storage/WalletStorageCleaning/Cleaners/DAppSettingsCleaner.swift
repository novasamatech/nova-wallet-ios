import Foundation
import Operation_iOS

final class DAppSettingsCleaner {
    private let authorizedDAppRepository: AnyDataProviderRepository<DAppSettings>

    init(authorizedDAppRepository: AnyDataProviderRepository<DAppSettings>) {
        self.authorizedDAppRepository = authorizedDAppRepository
    }
}

// MARK: WalletStorageCleaning

extension DAppSettingsCleaner: WalletStorageCleaning {
    func cleanStorage(
        for removedItems: @escaping () throws -> [MetaAccountModel]
    ) -> CompoundOperationWrapper<Void> {
        let fetchOptions = RepositoryFetchOptions()
        let fetchSettingsOperation = authorizedDAppRepository.fetchAllOperation(with: fetchOptions)

        let deletionBlock: () throws -> [String] = {
            let removedWallets = Set(try removedItems().map(\.metaId))
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
