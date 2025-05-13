import Foundation
import Operation_iOS

protocol CompoundDelegatedAccountFetchOperationFactory: DelegatedAccountFetchOperationFactoryProtocol {
    func supportsChain(with chainId: ChainModel.Id) -> Bool

    func addChainFactory(
        _ factory: DelegatedAccountFetchOperationFactoryProtocol,
        for chainId: ChainModel.Id
    )

    func removeChainFactory(for chainId: ChainModel.Id)
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
    func createFetchAllChangesOperation(
        at blockHash: Data?
    ) -> BaseOperation<[SyncChanges<ManagedMetaAccountModel>]> {
        OperationCombiningService(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            self.chainSyncFactories.map { $0.value.createChangesWrapper(at: blockHash) }
        }.longrunOperation()
    }

    func mapFetchResult(
        _ fetchResult: [SyncChanges<ManagedMetaAccountModel>]
    ) -> SyncChanges<ManagedMetaAccountModel> {
        var delegateStatusMap: [MetaAccountDelegationId: Set<DelegatedAccount.Status>] = [:]

        let filteredUpdates = fetchResult
            .flatMap(\.newOrUpdatedItems)
            .compactMap { managedMetaAccount -> ManagedMetaAccountModel? in
                guard
                    let delegationId = managedMetaAccount.info.delegationId(),
                    let status = managedMetaAccount.info.delegatedAccountStatus()
                else { return nil }

                guard delegateStatusMap[delegationId] == nil else {
                    delegateStatusMap[delegationId]?.insert(status)
                    return nil
                }

                delegateStatusMap[delegationId] = [status]

                return managedMetaAccount
            }

        let resultUpdates = filteredUpdates.map { managedMetaAccount in
            guard
                let delegationId = managedMetaAccount.info.delegationId(),
                let currentStatus = managedMetaAccount.info.delegatedAccountStatus(),
                let collectedStatuses = delegateStatusMap[delegationId],
                collectedStatuses.count > 1
            else { return managedMetaAccount }

            let resultStatus: DelegatedAccount.Status = if collectedStatuses.contains(.new) {
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
        at blockHash: Data?
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let fetchAllChangesOperation = createFetchAllChangesOperation(at: blockHash)

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
            let fetchResult = try fetchAllChangesOperation.extractNoCancellableResultData()

            return self.mapFetchResult(fetchResult)
        }

        mapOperation.addDependency(fetchAllChangesOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [fetchAllChangesOperation]
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
