import Foundation
import Operation_iOS

protocol DelegatedAccountSyncBarrierProtocol {
    func filter(_ changes: SyncChanges<ManagedMetaAccountModel>) -> SyncChanges<ManagedMetaAccountModel>
}

final class DelegatedAccountSyncBarrier {
    private let mutex = NSLock()
    private let logger: LoggerProtocol

    private var registeredDelegations: Set<MetaAccountDelegationId> = []

    init(logger: LoggerProtocol = Logger.shared) {
        self.logger = logger
    }
}

// MARK: - DelegatedAccountSyncBarrierProtocol

extension DelegatedAccountSyncBarrier: DelegatedAccountSyncBarrierProtocol {
    func filter(_ changes: SyncChanges<ManagedMetaAccountModel>) -> SyncChanges<ManagedMetaAccountModel> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let newOrUpdatedItems = changes.newOrUpdatedItems.filter { delegatedMetaAccount in
            guard let delegationId = delegatedMetaAccount.info.delegationId() else { return false }

            guard !registeredDelegations.contains(delegationId) else {
                return false
            }

            registeredDelegations.insert(delegationId)

            return true
        }

        return SyncChanges(
            newOrUpdatedItems: newOrUpdatedItems,
            removedItems: changes.removedItems
        )
    }
}
