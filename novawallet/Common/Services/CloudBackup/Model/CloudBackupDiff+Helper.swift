import Foundation

extension CloudBackupDiff {
    func getNewWallets() -> Set<MetaAccountModel> {
        let newWallets = self.compactMap { change in
            switch change {
            case let .new(remote):
                return remote
            case .delete, .updatedChainAccounts, .updatedMetadata:
                return nil
            }
        }
        
        return Set(newWallets)
    }
}
