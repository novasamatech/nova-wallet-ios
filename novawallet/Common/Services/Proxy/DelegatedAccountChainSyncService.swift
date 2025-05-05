import SubstrateSdk
import Operation_iOS
import BigInt

enum DelegatedAccount {
    case multisig(DiscoveredMultisig)
    case proxy(ProxyAccount)
}

protocol DelegatedAccountChainSyncServiceProtocol: ObservableSyncServiceProtocol {
    func sync(at blockHash: Data?)
}

final class DelegatedAccountChainSyncService: ObservableSyncService, AnyCancellableCleaning {
    let walletUpdateMediator: WalletUpdateMediating
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let chainModel: ChainModel
    let requestFactory: StorageRequestFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let eventCenter: EventCenterProtocol
    let chainWalletFilter: ProxySyncChainWalletFilter?

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private var pendingCall = CancellableCallStore()
    private let changesCalculator: ChainProxyChangesCalculator

    init(
        chainModel: ChainModel,
        walletUpdateMediator: WalletUpdateMediating,
        metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        chainRegistry: ChainRegistryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        chainWalletFilter: ProxySyncChainWalletFilter?
    ) {
        self.chainModel = chainModel
        self.chainRegistry = chainRegistry
        self.operationQueue = operationQueue
        self.walletUpdateMediator = walletUpdateMediator
        self.metaAccountsRepository = metaAccountsRepository
        self.workingQueue = workingQueue
        self.eventCenter = eventCenter
        self.chainWalletFilter = chainWalletFilter
        changesCalculator = .init(chainModel: chainModel)
        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        identityProxyFactory = IdentityProxyFactory(
            originChain: chainModel,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityOperationFactory
        )
    }

    override func performSyncUp() {
        performSync(at: nil)
    }

    override func stopSyncUp() {
        pendingCall.cancel()
    }
}

// MARK: Private

private extension DelegatedAccountChainSyncService {
    func performSync(at blockHash: Data?) {
        let chainId = chainModel.chainId
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            completeImmediate(ChainRegistryError.connectionUnavailable)
            return
        }

        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            completeImmediate(ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        pendingCall.cancel()
        
        let metaAccountsWrapper = createWalletsWrapper(
            for: chainWalletFilter,
            chain: chainModel
        )

        let delegatedAccountsListWrapper = createDelegatedAccountsListWrapper(
            connection: connection,
            runtimeProvider: runtimeProvider,
            metaAccountsWrapper: metaAccountsWrapper,
            blockHash: blockHash
        )

        let changesOperation = createChangesWrapper(
            delegatedAccountsListWrapper: delegatedAccountsListWrapper,
            metaAccountsWrapper: metaAccountsWrapper,
            identityProxyFactory: identityProxyFactory
        )

        let updateWrapper = walletUpdateMediator.saveChanges {
            try changesOperation.targetOperation.extractNoCancellableResultData()
        }

        updateWrapper.addDependency(wrapper: changesOperation)

        let compoundWrapper = CompoundOperationWrapper(
            targetOperation: updateWrapper.targetOperation,
            dependencies: changesOperation.allOperations + updateWrapper.dependencies
        )

        executeCancellable(
            wrapper: compoundWrapper,
            inOperationQueue: operationQueue,
            backingCallIn: pendingCall,
            runningCallbackIn: workingQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(update):
                DispatchQueue.main.async {
                    self?.eventCenter.notify(with: WalletsChanged(source: .byProxyService))

                    if update.isWalletSwitched {
                        self?.eventCenter.notify(with: SelectedWalletSwitched())
                    }
                }

                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    func createWalletsWrapper(
        for filter: ProxySyncChainWalletFilter?,
        chain: ChainModel
    ) -> CompoundOperationWrapper<[ManagedMetaAccountModel]> {
        let metaAccountsOperation = metaAccountsRepository.fetchAllOperation(with: .init())

        let filterOperation = ClosureOperation<[ManagedMetaAccountModel]> {
            let allWallets = try metaAccountsOperation.extractNoCancellableResultData()

            guard let filter = filter else {
                return allWallets
            }

            return allWallets.filter { filter(chain, $0.info) }
        }

        filterOperation.addDependency(metaAccountsOperation)

        return CompoundOperationWrapper(targetOperation: filterOperation, dependencies: [metaAccountsOperation])
    }
    
    func createDelegatedAccountsListWrapper(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[AccountId: [DelegatedAccount]]> {
        let proxyRepository = ChainProxyAccountsRepository(
            requestFactory: requestFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            blockHash: blockHash,
            operationQueue: operationQueue
        )
        let multisigRepository = MultisigAccountsRepository(chain: chainModel)

        let delegatedListWrapper = createDelegatedAccountsListWrapper(
            proxyRepository: proxyRepository,
            multisigRepository: multisigRepository,
            metaAccountsWrapper: metaAccountsWrapper,
            chainModel: chainModel
        )
        
        return delegatedListWrapper
    }

    func createDelegatedAccountsListWrapper(
        proxyRepository: ProxyAccountsRepositoryProtocol,
        multisigRepository: MultisigAccountsRepositoryProtocol,
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        chainModel: ChainModel
    ) -> CompoundOperationWrapper<[AccountId: [DelegatedAccount]]> {
        let accountsListWrapper: CompoundOperationWrapper<[AccountId: [DelegatedAccount]]>
        accountsListWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }
            
            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()

            let possibleProxiesList: [AccountId] = chainMetaAccounts.compactMap { wallet in
                guard wallet.info.type != .proxied else {
                    return nil
                }

                return wallet.info.fetch(for: chainModel.accountRequest())?.accountId
            }

            var possibleProxiesIds = Set(possibleProxiesList)
            
            return createDiscoverAccountsWrapper(
                proxyRepository: proxyRepository,
                multisigRepository: multisigRepository,
                possibleProxiesIds: possibleProxiesIds,
                previousProxiesIds: possibleProxiesIds,
                proxies: [:]
            )
        }
        
        accountsListWrapper.addDependency(wrapper: metaAccountsWrapper)
        
        return accountsListWrapper.insertingHead(operations: metaAccountsWrapper.allOperations)
    }
    
    func createDiscoverAccountsWrapper(
        proxyRepository: ProxyAccountsRepositoryProtocol,
        multisigRepository: MultisigAccountsRepositoryProtocol,
        possibleProxiesIds: Set<AccountId>,
        previousProxiesIds: Set<AccountId>,
        proxies: [ProxiedAccountId: [ProxyAccount]]
    ) -> CompoundOperationWrapper<[AccountId: [DelegatedAccount]]> {
        let proxiesWrapper = proxyRepository.fetchProxiedAccountsWrapper(with: possibleProxiesIds)
        let multisigWrapper = multisigRepository.fetchMultisigsWrapper(for: possibleProxiesIds)
        
        let resultWrapper: CompoundOperationWrapper<[AccountId: [DelegatedAccount]]>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }
            
            guard possibleProxiesIds != previousProxiesIds else {
                return .createWithResult(proxies.mapValues { $0.map { value in .proxy(value) } })
            }
            
            let proxies = try proxiesWrapper.targetOperation.extractNoCancellableResultData()
            
            return createDiscoverAccountsWrapper(
                proxyRepository: proxyRepository,
                multisigRepository: multisigRepository,
                possibleProxiesIds: possibleProxiesIds.union(Set(proxies.keys)),
                previousProxiesIds: possibleProxiesIds,
                proxies: proxies
            )
        }
        
        resultWrapper.addDependency(wrapper: proxiesWrapper)
        
        return resultWrapper.insertingHead(operations: proxiesWrapper.allOperations)
    }
    
    func createChangesWrapper(
        delegatedAccountsListWrapper: CompoundOperationWrapper<[AccountId: [DelegatedAccount]]>,
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId(
            for: {
                let delegatedAccounts = try delegatedAccountsListWrapper.targetOperation.extractNoCancellableResultData()
                return Array(delegatedAccounts.keys)
            }
        )

        identityWrapper.addDependency(wrapper: delegatedAccountsListWrapper)

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> { [changesCalculator] in
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()
            let remoteDelegatedAccounts = try delegatedAccountsListWrapper.targetOperation.extractNoCancellableResultData()

            return try changesCalculator.calculateUpdates(
                from: remoteDelegatedAccounts,
                chainMetaAccounts: chainMetaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(metaAccountsWrapper.targetOperation)
        mapOperation.addDependency(delegatedAccountsListWrapper.targetOperation)

        let dependencies = delegatedAccountsListWrapper.allOperations
            + identityWrapper.allOperations
            + metaAccountsWrapper.allOperations

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }
}

// MARK: DelegatedAccountChainSyncServiceProtocol

extension DelegatedAccountChainSyncService: DelegatedAccountChainSyncServiceProtocol {
    func sync(at blockHash: Data?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        if isSyncing {
            stopSyncUp()

            isSyncing = false
        }

        isSyncing = true

        performSync(at: blockHash)
    }
}
