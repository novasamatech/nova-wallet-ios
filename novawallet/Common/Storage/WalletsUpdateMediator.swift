import Foundation
import Operation_iOS

typealias NewSelectedWalletClosure = (Result<ManagedMetaAccountModel?, Error>) -> Void

struct WalletUpdateMediatingResult {
    let selectedWallet: ManagedMetaAccountModel?
    let isWalletSwitched: Bool
}

protocol WalletUpdateMediating {
    func saveChanges(
        _ changes: @escaping () throws -> SyncChanges<ManagedMetaAccountModel>
    ) -> CompoundOperationWrapper<WalletUpdateMediatingResult>
}

final class WalletUpdateMediator {
    struct ProcessingResult {
        let changes: SyncChanges<ManagedMetaAccountModel>
        let selectedWallet: ManagedMetaAccountModel?
    }

    let selectedWalletSettings: SelectedWalletSettings
    let repository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let walletsCleaner: WalletStorageCleaning
    let operationQueue: OperationQueue

    // TODO: Implement wallet cleaner usage
    init(
        selectedWalletSettings: SelectedWalletSettings,
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        walletsCleaner: WalletStorageCleaning,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.repository = repository
        self.walletsCleaner = walletsCleaner
        self.operationQueue = operationQueue
    }

    private static func nonDelegatedWalletReachable(
        from delegatedWallet: ManagedMetaAccountModel,
        wallets: [ManagedMetaAccountModel],
        removeIds: Set<MetaAccountModel.Id>
    ) -> Bool {
        var currentDelegatedSet: Set<MetaAccountModel.Id> = [delegatedWallet.info.metaId]
        var prevDelegated = currentDelegatedSet
        var foundWallets: [MetaAccountModel.Id: ManagedMetaAccountModel] = [delegatedWallet.info.metaId: delegatedWallet]

        repeat {
            let newReachableWallets: [ManagedMetaAccountModel] = currentDelegatedSet.flatMap { delegatedId in
                guard
                    let delegated = foundWallets[delegatedId],
                    let delegationId = delegated.info.delegationId() else {
                    return [ManagedMetaAccountModel]()
                }

                let filter: (ManagedMetaAccountModel) -> Bool = if let chainId = delegationId.chainId {
                    { $0.info.has(accountId: delegationId.delegateAccountId, chainId: chainId) }
                } else {
                    { $0.info.contains(accountId: delegationId.delegateAccountId) }
                }

                return wallets.filter(filter)
            }

            if newReachableWallets.contains(
                where: { !$0.info.isDelegated() && !removeIds.contains($0.info.metaId) }
            ) {
                return true
            }

            foundWallets = newReachableWallets.reduce(into: foundWallets) {
                $0[$1.info.metaId] = $1
            }

            prevDelegated = currentDelegatedSet
            currentDelegatedSet = Set(foundWallets.keys)
        } while prevDelegated != currentDelegatedSet

        return false
    }

    private static func includeDelegatedAccountsToRemoveSet(
        starting removeIds: Set<MetaAccountModel.Id>,
        wallets: [ManagedMetaAccountModel]
    ) -> Set<MetaAccountModel.Id> {
        var oldRemovedIds = removeIds
        var newRemovedIds = removeIds

        let allDelegatedAccounts = wallets.filter { $0.info.isDelegated() }

        // we can have nested delegated accounts so we make sure to remove them all

        repeat {
            let newAccountIdsToRemove = allDelegatedAccounts.filter { delegatedAccount in
                !nonDelegatedWalletReachable(
                    from: delegatedAccount,
                    wallets: wallets,
                    removeIds: newRemovedIds
                )
            }.map(\.identifier)

            oldRemovedIds = newRemovedIds
            newRemovedIds = newRemovedIds.union(Set(newAccountIdsToRemove))
        } while oldRemovedIds != newRemovedIds

        return newRemovedIds
    }

    private func delegatedAccountRemovalOperation(
        dependingOn allWalletsOperation: BaseOperation<[ManagedMetaAccountModel]>,
        changesClosure: @escaping () throws -> SyncChanges<ManagedMetaAccountModel>
    ) -> BaseOperation<SyncChanges<ManagedMetaAccountModel>> {
        ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
            let allWallets = try allWalletsOperation.extractNoCancellableResultData()

            let changes = try changesClosure()

            let allRemovedIds = Set(changes.removedItems.map(\.identifier))
            let newRemovedIds = Self.includeDelegatedAccountsToRemoveSet(starting: allRemovedIds, wallets: allWallets)

            let newRemovedWallets = allWallets.filter { newRemovedIds.contains($0.identifier) }

            let newUpdatedWallets = changes.newOrUpdatedItems.filter {
                !newRemovedIds.contains($0.identifier)
            }

            return SyncChanges(newOrUpdatedItems: newUpdatedWallets, removedItems: newRemovedWallets)
        }
    }

    func newSelectedWalletOperation(
        dependingOn changesOperation: BaseOperation<SyncChanges<ManagedMetaAccountModel>>,
        allWalletsOperation: BaseOperation<[ManagedMetaAccountModel]>
    ) -> BaseOperation<ProcessingResult> {
        ClosureOperation<ProcessingResult> {
            let changes = try changesOperation.extractNoCancellableResultData()

            // we want to change selected wallet if current one is removed or revoked as delegated account

            let newUpdatedWallets = changes.newOrUpdatedItems.map { wallet in
                if wallet.isSelected, wallet.info.delegatedAccountStatus() == .revoked {
                    return ManagedMetaAccountModel(info: wallet.info, isSelected: false, order: wallet.order)
                } else {
                    return wallet
                }
            }

            let allWallets = try allWalletsOperation.extractNoCancellableResultData()
            var newState = allWallets.reduce(into: [MetaAccountModel.Id: ManagedMetaAccountModel]()) { accum, wallet in
                accum[wallet.identifier] = wallet
            }

            newState = newUpdatedWallets.reduce(into: newState) { accum, wallet in
                accum[wallet.identifier] = wallet
            }

            newState = changes.removedItems.reduce(into: newState) { accum, wallet in
                accum[wallet.identifier] = nil
            }

            if let selectedWallet = newState.values.first(where: { $0.isSelected }) {
                let newChanges = SyncChanges(newOrUpdatedItems: newUpdatedWallets, removedItems: changes.removedItems)
                return ProcessingResult(changes: newChanges, selectedWallet: selectedWallet)
            } else {
                // if no selected wallets then select existing not delegated wallet
                let newSelectedWallet = newState.values.first { !$0.info.isDelegated() }.map {
                    ManagedMetaAccountModel(info: $0.info, isSelected: true, order: $0.order)
                }

                let newChanges = SyncChanges(
                    newOrUpdatedItems: newUpdatedWallets + (newSelectedWallet.map { [$0] } ?? []),
                    removedItems: changes.removedItems
                )

                return ProcessingResult(changes: newChanges, selectedWallet: newSelectedWallet)
            }
        }
    }

    func selectedWalletUpdateOperation(
        in settings: SelectedWalletSettings,
        dependingOn processingOperation: BaseOperation<ProcessingResult>
    ) -> BaseOperation<Bool> {
        ClosureOperation<Bool> {
            let result = try processingOperation.extractNoCancellableResultData()

            if settings.value == nil || result.selectedWallet?.info != settings.value {
                settings.setup()

                return true
            } else {
                return false
            }
        }
    }
}

extension WalletUpdateMediator: WalletUpdateMediating {
    func saveChanges(
        _ changes: @escaping () throws -> SyncChanges<ManagedMetaAccountModel>
    ) -> CompoundOperationWrapper<WalletUpdateMediatingResult> {
        let allWalletsOperation = repository.fetchAllOperation(
            with: .init(includesProperties: true, includesSubentities: true)
        )

        let delegatedAccountRemovalOperation = delegatedAccountRemovalOperation(
            dependingOn: allWalletsOperation,
            changesClosure: changes
        )

        delegatedAccountRemovalOperation.addDependency(allWalletsOperation)

        let newSelectedWalletOperation = newSelectedWalletOperation(
            dependingOn: delegatedAccountRemovalOperation,
            allWalletsOperation: allWalletsOperation
        )

        newSelectedWalletOperation.addDependency(delegatedAccountRemovalOperation)

        let saveOperation = repository.saveOperation({
            let changesResult = try newSelectedWalletOperation.extractNoCancellableResultData()

            return changesResult.changes.newOrUpdatedItems
        }, {
            let changesResult = try newSelectedWalletOperation.extractNoCancellableResultData()

            return changesResult.changes.removedItems.map(\.identifier)
        })

        saveOperation.addDependency(newSelectedWalletOperation)

        let selectedWalletUpdateOperation = selectedWalletUpdateOperation(
            in: selectedWalletSettings,
            dependingOn: newSelectedWalletOperation
        )

        selectedWalletUpdateOperation.addDependency(saveOperation)

        let resultOperation = ClosureOperation<WalletUpdateMediatingResult> {
            try saveOperation.extractNoCancellableResultData()
            let isWalletSwitched = try selectedWalletUpdateOperation.extractNoCancellableResultData()
            let currentWallet = try newSelectedWalletOperation.extractNoCancellableResultData().selectedWallet

            return .init(selectedWallet: currentWallet, isWalletSwitched: isWalletSwitched)
        }

        resultOperation.addDependency(saveOperation)
        resultOperation.addDependency(selectedWalletUpdateOperation)
        resultOperation.addDependency(newSelectedWalletOperation)

        let dependencies = [
            allWalletsOperation,
            delegatedAccountRemovalOperation,
            newSelectedWalletOperation,
            saveOperation,
            selectedWalletUpdateOperation
        ]

        return CompoundOperationWrapper(
            targetOperation: resultOperation,
            dependencies: dependencies
        )
    }
}
