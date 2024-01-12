import Foundation
import RobinHood

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
    let operationQueue: OperationQueue

    init(
        selectedWalletSettings: SelectedWalletSettings,
        repository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.repository = repository
        self.operationQueue = operationQueue
    }

    private func proxiedRemovalOperation(
        dependingOn allWalletsOperation: BaseOperation<[ManagedMetaAccountModel]>,
        changesClosure: @escaping () throws -> SyncChanges<ManagedMetaAccountModel>
    ) -> BaseOperation<SyncChanges<ManagedMetaAccountModel>> {
        ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
            let allWallets = try allWalletsOperation.extractNoCancellableResultData().sorted { wallet1, wallet2 in
                wallet1.order < wallet2.order
            }

            let changes = try changesClosure()

            let allRemovedIds = Set(changes.removedItems.map(\.identifier))

            let allProxieds = allWallets.filter {
                $0.info.type == .proxied && !allRemovedIds.contains($0.identifier)
            }

            let proxiedsToRemove = allProxieds.filter { proxiedWallet in
                guard
                    let chainAccount = proxiedWallet.info.chainAccounts.first,
                    let proxy = chainAccount.proxy else {
                    return false
                }

                return allWallets.allSatisfy { wallet in
                    guard !allRemovedIds.contains(wallet.identifier) else {
                        return true
                    }

                    return !wallet.info.has(accountId: proxy.accountId, chainId: chainAccount.chainId)
                }
            }

            let newRemovedWallets = changes.removedItems + proxiedsToRemove
            let newRemovedWalletsIds = Set(newRemovedWallets.map(\.identifier))

            let newUpdatedWallets = changes.newOrUpdatedItems.filter {
                !newRemovedWalletsIds.contains($0.info.identifier)
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

            // we want to change selected wallet if current one is removed or revoked as proxied

            let newUpdatedWallets = changes.newOrUpdatedItems.map { wallet in
                if wallet.isSelected, wallet.info.proxy()?.status == .revoked {
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
                let existingWallets = Set(newState.keys)
                let newSelectedWallet = allWallets.first {
                    $0.info.type != .proxied && existingWallets.contains($0.identifier)
                }.map {
                    ManagedMetaAccountModel(
                        info: $0.info,
                        isSelected: true,
                        order: $0.order
                    )
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

            if result.selectedWallet?.identifier != settings.value?.identifier || settings.value == nil {
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

        let proxiedsRemovalOperation = proxiedRemovalOperation(
            dependingOn: allWalletsOperation,
            changesClosure: changes
        )

        proxiedsRemovalOperation.addDependency(allWalletsOperation)

        let newSelectedWalletOperation = newSelectedWalletOperation(
            dependingOn: proxiedsRemovalOperation,
            allWalletsOperation: allWalletsOperation
        )

        newSelectedWalletOperation.addDependency(proxiedsRemovalOperation)

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
            proxiedsRemovalOperation,
            newSelectedWalletOperation,
            saveOperation,
            selectedWalletUpdateOperation
        ]

        return CompoundOperationWrapper(targetOperation: resultOperation, dependencies: dependencies)
    }
}
