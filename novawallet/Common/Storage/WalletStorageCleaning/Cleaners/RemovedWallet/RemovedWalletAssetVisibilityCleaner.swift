import Foundation
import Operation_iOS

final class RemovedWalletAssetVisibilityCleaner {
    private let visibilityRepository: AnyDataProviderRepository<AssetVisibilityLocal>
    private let settingsRepository: AnyDataProviderRepository<MetaAccountSettingsLocal>

    init(
        visibilityRepository: AnyDataProviderRepository<AssetVisibilityLocal>,
        settingsRepository: AnyDataProviderRepository<MetaAccountSettingsLocal>
    ) {
        self.visibilityRepository = visibilityRepository
        self.settingsRepository = settingsRepository
    }
}

// MARK: WalletStorageCleaning

extension RemovedWalletAssetVisibilityCleaner: WalletStorageCleaning {
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
        let fetchRowsOperation = visibilityRepository.fetchAllOperation(with: fetchOptions)
        let fetchSettingsOperation = settingsRepository.fetchAllOperation(with: fetchOptions)

        let removeRowsOperation = visibilityRepository.saveOperation({ [] }, {
            try fetchRowsOperation.extractNoCancellableResultData()
                .filter { removedWalletsIds.contains($0.metaId) }
                .map(\.identifier)
        })

        removeRowsOperation.addDependency(fetchRowsOperation)

        let removeSettingsOperation = settingsRepository.saveOperation({ [] }, {
            try fetchSettingsOperation.extractNoCancellableResultData()
                .filter { removedWalletsIds.contains($0.metaId) }
                .map(\.identifier)
        })

        removeSettingsOperation.addDependency(fetchSettingsOperation)

        let mergeOperation = ClosureOperation<Void> {
            try removeRowsOperation.extractNoCancellableResultData()
            try removeSettingsOperation.extractNoCancellableResultData()
        }

        mergeOperation.addDependency(removeRowsOperation)
        mergeOperation.addDependency(removeSettingsOperation)

        return CompoundOperationWrapper(
            targetOperation: mergeOperation,
            dependencies: [
                fetchRowsOperation,
                removeRowsOperation,
                fetchSettingsOperation,
                removeSettingsOperation
            ]
        )
    }
}
