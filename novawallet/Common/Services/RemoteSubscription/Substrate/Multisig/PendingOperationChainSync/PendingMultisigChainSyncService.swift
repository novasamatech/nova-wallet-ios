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
    private let localSyncFactory: PendingMultisigLocalSyncFactoryProtocol
    private let remoteFetchFactory: PendingMultisigRemoteFetchFactoryProtocol
    private let remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol
    private let operationManager: OperationManagerProtocol

    private var operationsLocalStorateProvider: StreamableProvider<Multisig.PendingOperation>?

    init(
        multisigAccount: DelegatedAccount.MultisigAccountModel,
        chain: ChainModel,
        localSyncFactory: PendingMultisigLocalSyncFactoryProtocol,
        remoteFetchFactory: PendingMultisigRemoteFetchFactoryProtocol,
        pendingMultisigLocalSubscriptionFactory: MultisigOperationsLocalSubscriptionFactoryProtocol,
        remoteOperationUpdateService: MultisigPendingOperationsUpdatingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.multisigAccount = multisigAccount
        self.chain = chain
        self.localSyncFactory = localSyncFactory
        self.remoteFetchFactory = remoteFetchFactory
        self.pendingMultisigLocalSubscriptionFactory = pendingMultisigLocalSubscriptionFactory
        self.remoteOperationUpdateService = remoteOperationUpdateService
        self.operationManager = operationManager
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

        syncPendingOperations()
    }

    override func stopSyncUp() {
        clear(streamableProvider: &operationsLocalStorateProvider)
        remoteOperationUpdateService.clearSubscription()
    }
}

// MARK: - Private

private extension PendingMultisigChainSyncService {
    func syncPendingOperations() {
        let remoteFetchWrapper = remoteFetchFactory.createFetchWrapper()

        configureRemoteFetchWrapper(targetOperation: remoteFetchWrapper.targetOperation)

        operationManager.enqueue(
            operations: remoteFetchWrapper.allOperations,
            in: .transient
        )
    }

    func configureRemoteFetchWrapper(targetOperation: BaseOperation<MultisigPendingOperationsMap>) {
        targetOperation.completionBlock = { [weak self] in
            guard let self else { return }

            do {
                let remoteOperations = try targetOperation.extractNoCancellableResultData()
                let localSyncWrapper = localSyncFactory.createSyncLocalWrapper(with: remoteOperations)

                configureLocalSyncWrapper(targetOperation: localSyncWrapper.targetOperation)

                operationManager.enqueue(
                    operations: localSyncWrapper.allOperations,
                    in: .sync
                )
            } catch {
                self.logger.error("Failed to fetch remote pending operations: \(error)")
            }
        }
    }

    func configureLocalSyncWrapper(targetOperation: BaseOperation<Set<Substrate.CallHash>>) {
        targetOperation.completionBlock = {
            do {
                let callHashes = try targetOperation.extractNoCancellableResultData()
                self.subscribeUpdates(for: callHashes)
            } catch {
                self.logger.error("Failed to sync local pending operations: \(error)")
            }
        }
    }

    func updateSubscriptions(adding callHashes: Set<Substrate.CallHash>) {
        let localHashesWrapper = localSyncFactory.createFetchLocalHashesWrapper()

        localHashesWrapper.targetOperation.completionBlock = { [weak self] in
            do {
                let localOperationsCallHashes = try localHashesWrapper
                    .targetOperation
                    .extractNoCancellableResultData()
                self?.subscribeUpdates(for: localOperationsCallHashes.union(callHashes))
            } catch {
                self?.logger.error("Failed to fetch local call hashes: \(error)")
            }
        }

        operationManager.enqueue(
            operations: localHashesWrapper.allOperations,
            in: .sync
        )
    }

    func subscribeUpdates(for callHashes: Set<Substrate.CallHash>) {
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
            let callHashesToSubscribe = changes
                .filter { $0.item?.multisigDefinition == nil }
                .compactMap { $0.item?.callHash }

            guard !callHashesToSubscribe.isEmpty else { return }

            updateSubscriptions(adding: Set(callHashesToSubscribe))
        case let .failure(error):
            logger.error("Failed to handle multisig pending operations: \(error), chainId: \(chain.chainId)")
        }
    }
}

// MARK: - MultisigPendingOperationsSubscriber

extension PendingMultisigChainSyncService: MultisigPendingOperationsSubscriber {
    func didReceiveUpdate(
        callHash: Substrate.CallHash,
        multisigDefinition: MultisigDefinitionWithTime?
    ) {
        let updateDefinitionWrapper = localSyncFactory.createUpdateDefinitionWrapper(
            for: callHash,
            multisigDefinition
        )

        operationManager.enqueue(
            operations: updateDefinitionWrapper.allOperations,
            in: .sync
        )
    }
}
