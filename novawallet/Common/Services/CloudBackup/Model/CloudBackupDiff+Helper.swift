import Foundation

extension CloudBackupDiff {
    func deriveNewWallets() -> Set<MetaAccountModel> {
        let newWallets: [MetaAccountModel] = compactMap { change in
            switch change {
            case let .new(remote):
                return remote
            case .delete, .updatedChainAccounts, .updatedMetadata:
                return nil
            }
        }

        return Set<MetaAccountModel>(newWallets)
    }
}
