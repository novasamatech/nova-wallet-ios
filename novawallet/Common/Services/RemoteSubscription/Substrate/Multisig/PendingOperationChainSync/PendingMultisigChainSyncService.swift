import Foundation
import SubstrateSdk
import Operation_iOS

protocol PendingMultisigChainSyncServiceProtocol: SyncServiceProtocol {}

final class PendingMultisigChainSyncService: BaseSyncService,
    PendingMultisigChainSyncServiceProtocol,
    AnyProviderAutoCleaning {
    let pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol

    private let multisigAccount: DelegatedAccount.MultisigAccountModel
    private let chain: ChainModel
    private let localStorageSyncService: PendingMultisigLocalStorageSyncServiceProtocol
    private let remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol

    private var operationsLocalStorateProvider: StreamableProvider<Multisig.PendingOperation>?

    init(
        multisigAccount: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel,
        localStorageSyncService: PendingMultisigLocalStorageSyncServiceProtocol,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol
    ) {
        self.multisigAccount = multisigAccount
        self.chain = chain
        self.localStorageSyncService = localStorageSyncService
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
        self.remoteOperationUpdateService = remoteOperationUpdateService
    }

    deinit {
        remoteOperationUpdateService.clearSubscription()
    }

    // MARK: - Overrides

    override func performSyncUp() {
        clear(streamableProvider: &operationsLocalStorateProvider)

        operationsLocalStorateProvider = subscribePendingOperations(
            for: multisigAccount.accountId,
            chainId: chain.chainId
        )

        localStorageSyncService.syncPendingOperations { [weak self] updatedCallHashes in
            self?.createManageSubscriptionsOperation(callHashes: updatedCallHashes)
        }
    }

    override func stopSyncUp() {
        clear(streamableProvider: &operationsLocalStorateProvider)
        remoteOperationUpdateService.clearSubscription()
    }
}

// MARK: - Private

private extension PendingMultisigChainSyncService {
    func createManageSubscriptionsOperation(callHashes: Set<CallHash>) {
        remoteOperationUpdateService.setupSubscription(
            subscriber: self,
            for: multisigAccount.accountId,
            callHashes: callHashes,
            chainId: chain.chainId
        )
    }
}

// MARK: - MultisigOperationsLocalSubscriptionHandler

extension PendingMultisigChainSyncService: MultisigOperationsLocalStorageSubscriber,
    MultisigOperationsLocalSubscriptionHandler {
    func handleMultisigPendingOperations(
        result: Result<
            [DataProviderChange<Multisig.PendingOperation>],
            any Error
        >
    ) {
        switch result {
        case let .success(changes):
            let callHashesToUpdate = changes
                .filter { $0.item?.multisigDefinition != nil }
                .compactMap { $0.item?.callHash }

            guard !callHashesToUpdate.isEmpty else { return }

            createManageSubscriptionsOperation(callHashes: Set(callHashesToUpdate))
        case let .failure(error):
            logger.error("Failed to handle multisig pending operations: \(error), chainId: \(chain.chainId)")
        }
    }
}

// MARK: - MultisigPendingOperationsSubscriber

extension PendingMultisigChainSyncService: MultisigPendingOperationsSubscriber {
    func didReceiveUpdate(
        callHash: CallHash,
        multisigDefinition: MultisigPallet.MultisigDefinition?
    ) {
        localStorageSyncService.updateDefinition(
            for: callHash,
            multisigDefinition
        )
    }
}
