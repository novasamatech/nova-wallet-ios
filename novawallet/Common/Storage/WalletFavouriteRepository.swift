import Foundation
import Operation_iOS

/**
 Lightweight write path for the per-wallet `isFavourite` flag.

 Favourite is a local-only UI preference — it is not part of the cloud backup
 payload. We therefore deliberately bypass `WalletUpdateMediator` (and the
 `CloudBackupSyncService` it triggers) here so that toggling a star does not
 cause an unnecessary cloud sync. All other wallet writes still go through the
 mediator unchanged.
 */
protocol WalletFavouriteRepositoryProtocol {
    func toggleFavouriteWrapper(for metaId: MetaAccountModel.Id) -> CompoundOperationWrapper<Void>
}

final class WalletFavouriteRepository {
    let repository: AnyDataProviderRepository<ManagedMetaAccountModel>

    init(repository: AnyDataProviderRepository<ManagedMetaAccountModel>) {
        self.repository = repository
    }
}

extension WalletFavouriteRepository: WalletFavouriteRepositoryProtocol {
    func toggleFavouriteWrapper(
        for metaId: MetaAccountModel.Id
    ) -> CompoundOperationWrapper<Void> {
        let fetchOperation = repository.fetchOperation(
            by: { metaId },
            options: RepositoryFetchOptions()
        )

        let saveOperation = repository.saveOperation({
            guard let existing = try fetchOperation.extractNoCancellableResultData() else {
                return []
            }
            let updated = existing.replacingFavourite(!existing.isFavourite)
            return [updated]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [fetchOperation]
        )
    }
}
