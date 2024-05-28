import Foundation

protocol CloudBackupReviewViewModelFactoryProtocol {
    func createViewModels(
        from changes: CloudBackupSyncResult.Changes,
        locale: Locale
    ) -> [CloudBackupReviewSectionViewModel]
}

final class CloudBackupReviewViewModelFactory {
    let primitiveFactory = WalletPrimitiveViewModelFactory()

    private func getWallet(from change: CloudBackupChange) -> MetaAccountModel {
        switch change {
        case let .new(remote):
            return remote
        case let .delete(local):
            return local
        case let .updatedChainAccounts(_, remote, _):
            return remote
        case let .updatedMetadata(_, remote):
            return remote
        }
    }

    private func getChangeType(from change: CloudBackupChange) -> CloudBackupReviewItemViewModel.ChangeType {
        switch change {
        case .new:
            return .new
        case .delete:
            return .removed
        case .updatedChainAccounts, .updatedMetadata:
            return .modified
        }
    }
}

extension CloudBackupReviewViewModelFactory: CloudBackupReviewViewModelFactoryProtocol {
    func createViewModels(
        from changes: CloudBackupSyncResult.Changes,
        locale: Locale
    ) -> [CloudBackupReviewSectionViewModel] {
        guard case let .updateLocal(updateLocal) = changes else {
            return []
        }

        let walletTypes = MetaAccountModelType.getDisplayPriorities()

        return walletTypes.compactMap { walletType in
            let items: [CloudBackupReviewItemViewModel] = updateLocal.changes.compactMap { change in
                let wallet = getWallet(from: change)

                guard wallet.type == walletType else {
                    return nil
                }

                return CloudBackupReviewItemViewModel(
                    metaId: wallet.metaId,
                    walletViewModel: primitiveFactory.createWalletInfo(from: wallet),
                    changeType: getChangeType(from: change)
                )
            }

            guard !items.isEmpty else {
                return nil
            }

            let header = primitiveFactory.createHeader(from: walletType, locale: locale)

            return CloudBackupReviewSectionViewModel(header: header, cells: items)
        }
    }
}
