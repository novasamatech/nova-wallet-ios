import Foundation
import RobinHood

typealias NewSelectedWalletClosure = (ManagedMetaAccountModel?) -> Void

protocol WalletUpdateMediating {
    func saveChanges(
        _ newOrUpdated: [ManagedMetaAccountModel],
        deleted: [ManagedMetaAccountModel],
        completion: NewSelectedWalletClosure?
    )
}

final class WalletUpdateMediator {
    let selectedWalletSettings: SelectedWalletSettings
    let repository: AnyDataProviderRepository<MetaAccountModel>
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    
    init(
        selectedWalletSettings: SelectedWalletSettings,
        repository: AnyDataProviderRepository<MetaAccountModel>,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.repository = repository
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
    }
    
    private func createProxiedRemovalOperation(
        dependingOn allWalletsOperation: BaseOperation<[ManagedMetaAccountModel]>,
        changes: SyncChanges<ManagedMetaAccountModel>
    ) -> BaseOperation<SyncChanges<ManagedMetaAccountModel>> {
        ClosureOperation<SyncChanges<ManagedMetaAccountModel>> {
            let allWallets = try allWalletsOperation.extractNoCancellableResultData()
            
            let allRemovedIds = Set(changes.removedItems.map({ $0.identifier }))
            
            let allProxieds = try allWallets.filter { $0.info.type == .proxied && !allRemovedIds.contains($0.identifier) }
            
            let proxiedsToRemove = allProxieds.filter { proxiedWallet in
                guard let proxyChainAccount = proxiedWallet.info.chainAccounts.first else {
                    return false
                }
                
                return allWallets.allSatisfy { wallet in
                    guard !allRemovedIds.contains(wallet.identifier) else {
                        return true
                    }
                    
                    return !wallet.info.has(
                        accountId: proxyChainAccount.accountId,
                        chainId: proxyChainAccount.chainId
                    )
                }
            }
            
            let newRemovedWallets = changes.removedItems + proxiedsToRemove
            let newRemovedWalletsIds = Set(newRemovedWallets.map({ $0.identifier }))
            
            let newUpdatedWallets = changes.newOrUpdatedItems.filter({ !newRemovedWalletsIds.contains($0.info.identifier) })
            
            return SyncChanges(newOrUpdatedItems: newUpdatedWallets, removedItems: newRemovedWallets)
        }
    }
    
    func newSelectedWalletOperation(
        dependingOn changesOperation: BaseOperation<SyncChanges<ManagedMetaAccountModel>>,
        allWalletsOperation: BaseOperation<[ManagedMetaAccountModel]>
    ) -> BaseOperation<SyncChanges> {
        ClosureOperation<SyncChanges> {
            let changes = changesOperation.extractNoCancellableResultData()
            
            // we want to change selected wallet if current one is removed or revoked as proxied
            
            let newUpdatedWallets = changes.newOrUpdatedItems.map { accum, wallet in
                if wallet.isSelected, wallet.proxy()?.status == .revoked {
                    return ManagedMetaAccountModel(
                        info: wallet.info,
                        isSelected: false,
                        order: wallet.order
                    )
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
            
            let hasSelectedWallet = newState.values.contains { $0.isSelected }
            
            if !hasSelectedWallet {
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
                
                return SyncChanges(
                    newOrUpdatedItems: newUpdatedWallets + ([newSelectedWallet] ?? []),
                    removedItems: changes.removedItems
                )
            } else {
                return SyncChanges(newOrUpdatedItems: newUpdatedWallets, removedItems: changes.removedItems)
            }
        }
    }
}

extension WalletUpdateMediator: WalletUpdateMediating {
    func saveChanges(
        _ changes: SyncChanges<ManagedMetaAccountModel>,
        completion: NewSelectedWalletClosure?
    ) {
        let allWalletsOperation = repository.fetchAllOperation(with: .init(includesProperties: true, includesSubentities: true))
        
        let proxiedsRemovalOperation = createProxiedRemovalOperation(
            dependingOn: allWalletsOperation,
            changes: changes
        )
        
        proxiedsRemovalOperation.addDependency(allWalletsOperation)
    }
}
