import Foundation

extension CloudBackupDiff {
    func deriveNewWallets() -> Set<MetaAccountModel> {
        let newWallets: [MetaAccountModel] = compactMap { change in
            switch change {
            case let .new(remote):
                return remote
            case .delete, .updatedChainAccounts, .updatedMainAccounts, .updatedMetadata:
                return nil
            }
        }

        return Set<MetaAccountModel>(newWallets)
    }

    var hasNewWallets: Bool {
        contains { change in
            if case .new = change {
                return true
            } else {
                return false
            }
        }
    }

    var hasChainAccountChanges: Bool {
        contains { change in
            if case .updatedChainAccounts = change {
                return true
            } else {
                return false
            }
        }
    }

    var hasWalletRemoves: Bool {
        contains { change in
            if case .delete = change {
                return true
            } else {
                return false
            }
        }
    }
}
