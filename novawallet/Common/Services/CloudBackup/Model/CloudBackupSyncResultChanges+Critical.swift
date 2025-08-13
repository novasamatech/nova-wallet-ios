import Foundation

extension CloudBackupSyncResult.Changes {
    var isDestructive: Bool {
        switch self {
        case .updateRemote, .updateByUnion:
            return false
        case let .updateLocal(updateLocal):
            return updateLocal.changes.contains { change in
                switch change {
                case .delete, .updatedChainAccounts, .updatedMainAccounts:
                    return true
                case .new, .updatedMetadata:
                    return false
                }
            }
        }
    }
}
