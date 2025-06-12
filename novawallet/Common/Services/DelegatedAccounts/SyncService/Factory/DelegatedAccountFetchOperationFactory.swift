import Foundation
import Operation_iOS

protocol CompoundDelegatedAccountFetchOperationFactory {
    func createChangesWrapper(
        for chainId: ChainModel.Id?,
        at blockHash: Data?,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>>

    func supportsChain(with chainId: ChainModel.Id) -> Bool

    func addChainFactory(
        _ factory: DelegatedAccountFetchOperationFactoryProtocol,
        for chainId: ChainModel.Id
    )

    func removeChainFactory(for chainId: ChainModel.Id)
}

extension CompoundDelegatedAccountFetchOperationFactory {
    func createChangesWrapper(
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        createChangesWrapper(
            for: nil,
            at: nil,
            metaAccountsClosure: metaAccountsClosure
        )
    }
}

final class DelegatedAccountFetchOperationFactory {
    let operationQueue: OperationQueue

    @Atomic(defaultValue: [:])
    private var chainSyncFactories: [ChainModel.Id: DelegatedAccountFetchOperationFactoryProtocol]

    init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }
}

// MARK: - Private

private extension DelegatedAccountFetchOperationFactory {
    func mapFetchResult(
        _ fetchResult: [SyncChanges<ManagedMetaAccountModel>]
    ) -> SyncChanges<ManagedMetaAccountModel> {
        var delegateStatusMap: [MetaAccountDelegationId: (Set<DelegatedAccount.Status>, ManagedMetaAccountModel)]

        delegateStatusMap = fetchResult
            .flatMap(\.newOrUpdatedItems)
            .reduce(into: [:]) { acc, managedMetaAccount in
                guard
                    let delegationId = managedMetaAccount.info.delegationId,
                    let status = managedMetaAccount.info.delegatedAccountStatus()
                else { return }

                if acc[delegationId] == nil {
                    acc[delegationId] = ([status], managedMetaAccount)
                } else {
                    acc[delegationId]?.0.insert(status)
                }
            }

        let resultUpdates = delegateStatusMap.map { delegationId, value in
            let collectedStatuses = value.0
            let managedMetaAccount = value.1

            guard
                collectedStatuses.count > 1,
                let currentStatus = managedMetaAccount.info.delegatedAccountStatus()
            else { return managedMetaAccount }

            // We don't want to overwrite revoke status for chain-specific delegation
            // since the only revoke status comes for the delegation's chain

            let chainSpecificRevoke = delegationId.chainId != nil && collectedStatuses.contains(.revoked)

            let resultStatus: DelegatedAccount.Status = if chainSpecificRevoke {
                .revoked
            } else if collectedStatuses.contains(.new) {
                .new
            } else if collectedStatuses.contains(.active) {
                .active
            } else {
                .revoked
            }

            return managedMetaAccount.replacingInfo(
                managedMetaAccount.info.replacingDelegatedAccountStatus(
                    from: currentStatus,
                    to: resultStatus
                )
            )
        }

        return SyncChanges(
            newOrUpdatedItems: resultUpdates,
            removedItems: fetchResult.flatMap(\.removedItems)
        )
    }
}

// MARK: - CompoundDelegatedAccountFetchOperationFactory

extension DelegatedAccountFetchOperationFactory: CompoundDelegatedAccountFetchOperationFactory {
    func createChangesWrapper(
        for chainId: ChainModel.Id?,
        at blockHash: Data?,
        metaAccountsClosure: @escaping () throws -> [ManagedMetaAccountModel]
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let wrappers = chainSyncFactories.map { id, factory in
            factory.createChangesWrapper(
                metaAccountsClosure: metaAccountsClosure,
                at: chainId == id ? blockHash : nil
            )
        }

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
            self.mapFetchResult(
                try wrappers.compactMap { try $0.targetOperation.extractNoCancellableResultData() }
            )
        }

        wrappers.forEach { mapOperation.addDependency($0.targetOperation) }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: wrappers.flatMap(\.allOperations)
        )
    }

    func supportsChain(with chainId: ChainModel.Id) -> Bool {
        chainSyncFactories[chainId] != nil
    }

    func addChainFactory(
        _ factory: DelegatedAccountFetchOperationFactoryProtocol,
        for chainId: ChainModel.Id
    ) {
        chainSyncFactories[chainId] = factory
    }

    func removeChainFactory(for chainId: ChainModel.Id) {
        chainSyncFactories[chainId] = nil
    }
}
