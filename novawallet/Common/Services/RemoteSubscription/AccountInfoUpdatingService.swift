import Foundation
import RobinHood

protocol AccountInfoUpdatingServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class AccountInfoUpdatingService {
    struct SubscriptionInfo {
        let subscriptionId: UUID
        let accountId: AccountId
    }

    private(set) var selectedMetaAccount: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    let eventCenter: EventCenterProtocol
    let storageFacade: StorageFacadeProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    private var subscribedChains: [ChainModel.Id: SubscriptionInfo] = [:]

    private let mutex = NSLock()

    deinit {
        removeAllSubscriptions()
    }

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        selectedMetaAccount = selectedAccount
        self.chainRegistry = chainRegistry
        self.remoteSubscriptionService = remoteSubscriptionService
        self.storageFacade = storageFacade
        self.eventCenter = eventCenter
        self.storageRequestFactory = storageRequestFactory
        self.operationManager = operationManager
        self.logger = logger
        repositoryFactory = SubstrateRepositoryFactory(storageFacade: storageFacade)
    }

    private func removeAllSubscriptions() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        for chainId in subscribedChains.keys {
            removeSubscription(for: chainId)
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        for change in changes {
            switch change {
            case let .insert(newItem):
                addSubscriptionIfNeeded(for: newItem)
            case .update:
                break
            case let .delete(deletedIdentifier):
                removeSubscription(for: deletedIdentifier)
            }
        }
    }

    private func addSubscriptionIfNeeded(for chain: ChainModel) {
        guard
            let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId,
            let address = try? accountId.toAddress(using: chain.chainFormat) else {
            logger.error("Couldn't create account for chain \(chain.chainId)")
            return
        }

        guard subscribedChains[chain.chainId] == nil else {
            return
        }

        let txStorage = repositoryFactory.createTxRepository(for: address, chainId: chain.chainId)
        let contactOperationFactory = WalletContactOperationFactory(
            storageFacade: storageFacade,
            targetAddress: address
        )

        let transactionSubscription = TransactionSubscription(
            chainRegistry: chainRegistry,
            accountId: accountId,
            chainModel: chain,
            txStorage: txStorage,
            contactOperationFactory: contactOperationFactory,
            storageRequestFactory: storageRequestFactory,
            operationManager: operationManager,
            eventCenter: eventCenter,
            logger: logger
        )

        let subscriptionHandlingFactory = AccountInfoSubscriptionHandlingFactory(
            transactionSubscription: transactionSubscription,
            eventCenter: eventCenter
        )

        let maybeSubscriptionId = remoteSubscriptionService.attachToAccountInfo(
            of: accountId,
            chainId: chain.chainId,
            chainFormat: chain.chainFormat,
            queue: nil,
            closure: nil,
            subscriptionHandlingFactory: subscriptionHandlingFactory
        )

        if let subsciptionId = maybeSubscriptionId {
            subscribedChains[chain.chainId] = SubscriptionInfo(
                subscriptionId: subsciptionId,
                accountId: accountId
            )
        }
    }

    private func removeSubscription(for chainId: ChainModel.Id) {
        guard let subscriptionInfo = subscribedChains[chainId] else {
            logger.error("Expected to remove subscription but not found for \(chainId)")
            return
        }

        subscribedChains[chainId] = nil

        remoteSubscriptionService.detachFromAccountInfo(
            for: subscriptionInfo.subscriptionId,
            accountId: subscriptionInfo.accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }

    private func subscribeToChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .global(qos: .userInitiated)
        ) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    private func unsubscribeFromChains() {
        chainRegistry.chainsUnsubscribe(self)

        removeAllSubscriptions()
    }
}

extension AccountInfoUpdatingService: AccountInfoUpdatingServiceProtocol {
    func setup() {
        subscribeToChains()
    }

    func throttle() {
        unsubscribeFromChains()
    }

    func update(selectedMetaAccount: MetaAccountModel) {
        unsubscribeFromChains()

        self.selectedMetaAccount = selectedMetaAccount

        subscribeToChains()
    }
}
