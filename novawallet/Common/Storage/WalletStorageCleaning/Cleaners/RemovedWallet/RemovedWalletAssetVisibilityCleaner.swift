import Foundation
import Operation_iOS

final class RemovedWalletAssetVisibilityCleaner {
    private let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
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

        let visibilityRepository = AssetVisibilityRepositoryFactory.createVisibilityRepository(
            for: removedWalletsIds,
            using: storageFacade
        )
        let settingsRepository = AssetVisibilityRepositoryFactory.createSettingsRepository(
            for: removedWalletsIds,
            using: storageFacade
        )

        let fetchOptions = RepositoryFetchOptions()
        let fetchRowsOperation = visibilityRepository.fetchAllOperation(with: fetchOptions)
        let fetchSettingsOperation = settingsRepository.fetchAllOperation(with: fetchOptions)

        let removeRowsOperation = visibilityRepository.saveOperation({ [] }, {
            try fetchRowsOperation.extractNoCancellableResultData().map(\.identifier)
        })

        removeRowsOperation.addDependency(fetchRowsOperation)

        let removeSettingsOperation = settingsRepository.saveOperation({ [] }, {
            try fetchSettingsOperation.extractNoCancellableResultData().map(\.identifier)
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
