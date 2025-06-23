import Foundation
import SubstrateSdk
import Operation_iOS

protocol MultisigPendingOperationsSyncServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

class MultisigPendingOperationsSyncService {
    private let mutex = NSLock()

    private let chainRegistry: ChainRegistryProtocol
    private let callDataSyncService: MultisigCallDataSyncServiceProtocol
    private let chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol
    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol?

    private var selectedMetaAccount: MetaAccountModel {
        didSet {}
    }

    private var pendingOperationsChainSyncServices: [ChainModel.Id: PendingMultisigChainSyncServiceProtocol] = [:]

    private var knownCallData: [Multisig.PendingOperation.Key: JSON] = [:]

    init(
        selectedMetaAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        callDataSyncService: MultisigCallDataSyncServiceProtocol,
        chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.sync.service"),
        logger: LoggerProtocol? = nil
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRegistry = chainRegistry
        self.callDataSyncService = callDataSyncService
        self.chainSyncServiceFactory = chainSyncServiceFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
        self.logger = logger

        subscribeChains()
    }
}

// MARK: - Private

private extension MultisigPendingOperationsSyncService {
    func performSetup() {
        subscribeCallDataSync()
    }

    func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue,
            filterStrategy: .hasMultisig
        ) { [weak self] changes in
            guard let self else { return }

            mutex.lock()

            handleChain(changes)

            mutex.unlock()
        }
    }

    func handleChain(_ changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(chain), let .update(chain):
                callDataSyncService.addSyncing(for: chain)
                setupChainSyncService(for: chain)
            case let .delete(chainId):
                callDataSyncService.stopSyncing(for: chainId)
            }
        }
    }

    func stopSyncUpChainSyncServices() {
        pendingOperationsChainSyncServices.forEach { $0.value.stopSyncUp() }
    }

    func subscribeCallDataSync() {
        callDataSyncService.addObserver(
            self,
            sendOnSubscription: true
        )
    }

    func setupChainSyncService(for chain: ChainModel) {
        guard
            let multisigAccount = selectedMetaAccount.multisigAccount?.multisig,
            pendingOperationsChainSyncServices[chain.chainId] == nil
        else { return }

        let service = chainSyncServiceFactory.createMultisigChainSyncService(
            for: chain,
            selectedMultisigAccount: multisigAccount,
            knownCallData: knownCallData,
            operationQueue: operationQueue
        )

        pendingOperationsChainSyncServices[chain.chainId] = service

        service.setup()
    }

    func updateChainSyncServices() {
        stopSyncUpChainSyncServices()

        pendingOperationsChainSyncServices.keys
            .compactMap { chainRegistry.getChain(for: $0) }
            .forEach { chain in
                pendingOperationsChainSyncServices[chain.chainId]?.stopSyncUp()
                pendingOperationsChainSyncServices[chain.chainId] = nil
                setupChainSyncService(for: chain)
            }
    }
}

// MARK: - MultisigPendingOperationsSyncServiceProtocol

extension MultisigPendingOperationsSyncService: MultisigPendingOperationsSyncServiceProtocol {
    func setup() {
        mutex.lock()
        defer { mutex.unlock() }

        performSetup()
    }

    func throttle() {
        mutex.lock()
        defer { mutex.unlock() }

        stopSyncUpChainSyncServices()
        callDataSyncService.stopSyncUp()
    }

    func update(selectedMetaAccount: MetaAccountModel) {
        mutex.lock()
        defer { mutex.unlock() }

        guard selectedMetaAccount.metaId != self.selectedMetaAccount.metaId else { return }

        self.selectedMetaAccount = selectedMetaAccount

        if selectedMetaAccount.multisigAccount != nil {
            updateChainSyncServices()
        } else {
            stopSyncUpChainSyncServices()
            pendingOperationsChainSyncServices = [:]
        }
    }
}

// MARK: - MultisigCallDataObserver

extension MultisigPendingOperationsSyncService: MultisigCallDataObserver {
    func didReceive(newCallData: [Multisig.PendingOperation.Key: MultisigCallOrHash]) {
        mutex.lock()
        defer { mutex.unlock() }

        knownCallData.merge(
            newCallData.reduce(into: [:]) { $0[$1.key] = $1.value.call },
            uniquingKeysWith: { $1 }
        )

        pendingOperationsChainSyncServices.forEach {
            $0.value.updatePendingOperations(using: newCallData)
        }
    }
}

// MARK: - Errors

enum MultisigPendingOperationsSyncError: Error {
    case noChainMatchingMultisigAccount
    case multisigAccountUnavailable
    case localPendingOperationUnavailable
}
