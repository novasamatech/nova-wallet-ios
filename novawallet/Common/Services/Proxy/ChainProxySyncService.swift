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
            identityProxyFactory: identityProxyFactory,
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
        identityProxyFactory: IdentityProxyFactoryProtocol,
        chainModel: ChainModel
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let proxyListOperation = ClosureOperation<[ProxiedAccountId: [ProxyAccount]]> {
            let proxyList = try proxyListWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()

            let possibleProxiesList: [AccountId] = chainMetaAccounts.compactMap { wallet in
                guard wallet.info.type != .proxied else {
                    return nil
                }

                return wallet.info.fetch(for: chainModel.accountRequest())?.accountId
            }

            var possibleProxiesIds = Set(possibleProxiesList)
            var prevProxiesIds = possibleProxiesIds
            var proxies: [ProxiedAccountId: [ProxyAccount]] = [:]

            repeat {
                // We only need remote proxieds for current proxies and we don't support delaed proxies
                proxies = proxyList.compactMapValues { accounts in
                    accounts.filter {
                        !$0.hasDelay && possibleProxiesIds.contains($0.accountId)
                    }
                }.filter { !$0.value.isEmpty }

                prevProxiesIds = possibleProxiesIds
                possibleProxiesIds = possibleProxiesIds.union(Set(proxies.keys))

            } while possibleProxiesIds != prevProxiesIds

            return proxies
        }

        proxyListOperation.addDependency(proxyListWrapper.targetOperation)
        proxyListOperation.addDependency(metaAccountsWrapper.targetOperation)

        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId(
            for: {
                let proxieds = try proxyListOperation.extractNoCancellableResultData()
                return Array(proxieds.keys)
            }
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
