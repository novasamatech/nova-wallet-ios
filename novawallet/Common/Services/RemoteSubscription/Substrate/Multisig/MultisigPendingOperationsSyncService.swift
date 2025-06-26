import Foundation
import SubstrateSdk
import Operation_iOS

protocol MultisigPendingOperationsServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class MultisigPendingOperationsService {
    private let mutex = NSLock()

    private let chainRegistry: ChainRegistryProtocol
    private let callDataSyncService: MultisigCallDataSyncServiceProtocol
    private let chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol
    private let workingQueue: DispatchQueue
    private let logger: LoggerProtocol?

    private var selectedMetaAccount: MetaAccountModel

    private var chains: [ChainModel.Id: ChainModel] = [:]
    private var pendingOperationsChainSyncServices: [ChainModel.Id: PendingMultisigChainSyncServiceProtocol] = [:]

    init(
        selectedMetaAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        callDataSyncService: MultisigCallDataSyncServiceProtocol,
        chainSyncServiceFactory: PendingMultisigChainSyncServiceFactoryProtocol,
        workingQueue: DispatchQueue = DispatchQueue(label: "com.nova.wallet.pending.multisigs.sync.service"),
        logger: LoggerProtocol? = nil
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainRegistry = chainRegistry
        self.callDataSyncService = callDataSyncService
        self.chainSyncServiceFactory = chainSyncServiceFactory
        self.workingQueue = workingQueue
        self.logger = logger
    }
}

// MARK: - Private

private extension MultisigPendingOperationsService {
    func performSetup() {
        callDataSyncService.startSyncUp()
        subscribeChains()
    }

    func performStop() {
        chainRegistry.chainsUnsubscribe(self)
        clearChainSyncServices()
        callDataSyncService.stopSyncUp()
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
                chains[chain.chainId] = chain
                callDataSyncService.addSyncing(for: chain)
                setupChainSyncService(for: chain)
            case let .delete(chainId):
                chains[chainId] = nil
                callDataSyncService.stopSyncing(for: chainId)
            }
        }
    }

    func clearChainSyncServices() {
        stopSyncUpChainSyncServices()
        pendingOperationsChainSyncServices = [:]
    }

    func stopSyncUpChainSyncServices() {
        pendingOperationsChainSyncServices.forEach { $0.value.stopSyncUp() }
    }

    func setupChainSyncService(for chain: ChainModel) {
        guard
            let multisigAccount = selectedMetaAccount.multisigAccount?.multisig,
            pendingOperationsChainSyncServices[chain.chainId] == nil
        else { return }

        let service = chainSyncServiceFactory.createMultisigChainSyncService(
            for: chain,
            selectedMultisigAccount: multisigAccount
        )

        pendingOperationsChainSyncServices[chain.chainId] = service

        service.setup()
    }

    func updateChainSyncServices() {
        stopSyncUpChainSyncServices()

        chains.values.forEach {
            pendingOperationsChainSyncServices[$0.chainId] = nil
            setupChainSyncService(for: $0)
        }
    }
}

// MARK: - MultisigPendingOperationsServiceProtocol

extension MultisigPendingOperationsService: MultisigPendingOperationsServiceProtocol {
    func setup() {
        mutex.lock()
        defer { mutex.unlock() }

        performSetup()
    }

    func throttle() {
        mutex.lock()
        defer { mutex.unlock() }

        performStop()
    }

    func update(selectedMetaAccount: MetaAccountModel) {
        mutex.lock()
        defer { mutex.unlock() }

        guard selectedMetaAccount.metaId != self.selectedMetaAccount.metaId else { return }

        self.selectedMetaAccount = selectedMetaAccount

        if selectedMetaAccount.multisigAccount != nil {
            updateChainSyncServices()
        } else {
            clearChainSyncServices()
        }
    }
}

// MARK: - Errors

enum MultisigPendingOperationsSyncError: Error {
    case noChainMatchingMultisigAccount
    case multisigAccountUnavailable
    case localPendingOperationUnavailable
}
