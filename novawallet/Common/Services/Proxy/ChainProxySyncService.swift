import SubstrateSdk
import Operation_iOS
import BigInt

protocol ChainProxySyncServiceProtocol: ObservableSyncServiceProtocol {
    func sync(at blockHash: Data?)
}

final class ChainProxySyncService: ObservableSyncService, ChainProxySyncServiceProtocol, AnyCancellableCleaning {
    let walletUpdateMediator: WalletUpdateMediating
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let proxyOperationFactory: ProxyOperationFactoryProtocol
    let chainModel: ChainModel
    let requestFactory: StorageRequestFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
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
        proxyOperationFactory: ProxyOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        chainWalletFilter: ProxySyncChainWalletFilter?
    ) {
        self.chainModel = chainModel
        self.chainRegistry = chainRegistry
        self.proxyOperationFactory = proxyOperationFactory
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
        identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
    }

    override func performSyncUp() {
        performSync(at: nil)
    }

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

        let proxyListWrapper = proxyOperationFactory.fetchProxyList(
            requestFactory: requestFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            at: blockHash
        )

        let walletsWrapper = createWalletsWrapper(for: chainWalletFilter, chain: chainModel)

        let changesOperation = changesOperation(
            proxyListWrapper: proxyListWrapper,
            metaAccountsWrapper: walletsWrapper,
            connection: connection,
            runtimeProvider: runtimeProvider,
            identityOperationFactory: identityOperationFactory,
            chainModel: chainModel
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
                    self?.eventCenter.notify(with: AccountsChanged(method: .automatically))

                    if update.isWalletSwitched {
                        self?.eventCenter.notify(with: SelectedAccountChanged())
                    }
                }

                self?.completeImmediate(nil)
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    private func createWalletsWrapper(
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

    private func changesOperation(
        proxyListWrapper: CompoundOperationWrapper<[ProxiedAccountId: [ProxyAccount]]>,
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        chainModel: ChainModel
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let proxyListOperation = ClosureOperation<[ProxiedAccountId: [ProxyAccount]]> {
            let proxyList = try proxyListWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()

            let notProxiedAccountIdList: [AccountId] = chainMetaAccounts.compactMap { wallet in
                guard wallet.info.type != .proxied else {
                    return nil
                }

                return wallet.info.fetch(for: chainModel.accountRequest())?.accountId
            }

            let notProxiedAccountIds = Set(notProxiedAccountIdList)

            // We only need remote proxieds for proxies we have locally and we don't support delaed proxies
            let proxies = proxyList.compactMapValues { accounts in
                accounts.filter {
                    !$0.hasDelay && notProxiedAccountIds.contains($0.accountId)
                }
            }.filter { !$0.value.isEmpty }

            return proxies
        }
        proxyListOperation.addDependency(proxyListWrapper.targetOperation)
        proxyListOperation.addDependency(metaAccountsWrapper.targetOperation)

        let identityWrapper = identityOperationFactory.createIdentityWrapperByAccountId(
            for: {
                let proxieds = try proxyListOperation.extractNoCancellableResultData()
                return Array(proxieds.keys)
            },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainModel.chainFormat
        )

        identityWrapper.addDependency(operations: [proxyListOperation])

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> { [changesCalculator] in
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()
            let remoteProxieds = try proxyListOperation.extractNoCancellableResultData()

            return try changesCalculator.calculateUpdates(
                from: remoteProxieds,
                chainMetaAccounts: chainMetaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(metaAccountsWrapper.targetOperation)
        mapOperation.addDependency(proxyListOperation)

        let dependencies = proxyListWrapper.allOperations + identityWrapper.allOperations +
            [proxyListOperation] + metaAccountsWrapper.allOperations

        return .init(targetOperation: mapOperation, dependencies: dependencies)
    }

    override func stopSyncUp() {
        pendingCall.cancel()
    }
}
