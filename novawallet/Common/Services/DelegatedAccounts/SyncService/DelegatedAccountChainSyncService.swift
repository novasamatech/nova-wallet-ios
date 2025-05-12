import SubstrateSdk
import Operation_iOS
import BigInt

protocol DelegatedAccountProtocol {
    var accountId: AccountId { get }
}

private struct DiscoveringAccountIds {
    let possibleAccountIds: Set<AccountId>
    let knownAccountIds: Set<AccountId>
    let discoveredAccounts: [AccountId: [DelegatedAccountProtocol]]
}

protocol DelegatedAccountChainSyncServiceProtocol: ObservableSyncServiceProtocol {
    func sync(at blockHash: Data?)
}

final class DelegatedAccountChainSyncService: ObservableSyncService, AnyCancellableCleaning {
    let walletUpdateMediator: WalletUpdateMediating
    let metaAccountsRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    let chainRegistry: ChainRegistryProtocol
    let chainModel: ChainModel
    let accountSourceFactory: DelegatedAccountSourceFactoryProtocol
    let requestFactory: StorageRequestFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let eventCenter: EventCenterProtocol
    let chainWalletFilter: ProxySyncChainWalletFilter?

    private let operationQueue: OperationQueue
    private let workingQueue: DispatchQueue
    private var pendingCall = CancellableCallStore()
    private let changesCalculator: DelegatedAccountsChangesCalcualtorProtocol

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
        changesCalculator = DelegatedAccountsChangesCalculator(chainModel: chainModel)
        requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )
        accountSourceFactory = DelegatedAccountSourcesFactory(
            chain: chainModel,
            chainRegistry: chainRegistry,
            requestFactory: requestFactory
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
        pendingCall.cancel()

        let metaAccountsWrapper = createWalletsWrapper(
            for: chainWalletFilter,
            chain: chainModel
        )

        let delegatedAccountsListWrapper = createDelegatedAccountsListWrapper(
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
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        blockHash: Data?
    ) -> CompoundOperationWrapper<[AccountId: [DelegatedAccountProtocol]]> {
        let sources = accountSourceFactory.createSources(for: blockHash)

        let accountsListWrapper: CompoundOperationWrapper<[AccountId: [DelegatedAccountProtocol]]>
        accountsListWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()

            let possibleDelegatedAccountsList: [AccountId] = chainMetaAccounts.compactMap { wallet in
                guard !wallet.info.isDelegated() else { return nil }

                return wallet.info.fetch(for: self.chainModel.accountRequest())?.accountId
            }

            let discoveringAccounds = DiscoveringAccountIds(
                possibleAccountIds: Set(possibleDelegatedAccountsList),
                knownAccountIds: Set(possibleDelegatedAccountsList),
                discoveredAccounts: [:]
            )

            return createDiscoverAccountsWrapper(
                delegatedAccountsSources: sources,
                discoveringAccountIds: discoveringAccounds
            )
        }

        accountsListWrapper.addDependency(wrapper: metaAccountsWrapper)

        return accountsListWrapper.insertingHead(operations: metaAccountsWrapper.allOperations)
    }

    func createAccountsFetchWrapper(
        for sources: [DelegatedAccountsRepositoryProtocol],
        accountIds: Set<AccountId>
    ) -> CompoundOperationWrapper<[AccountId: [DelegatedAccountProtocol]]> {
        let fetchWrappers = sources.map { $0.fetchDelegatedAccountsWrapper(for: accountIds) }

        let mapOperation = ClosureOperation<[AccountId: [DelegatedAccountProtocol]]> {
            try fetchWrappers.reduce(into: [:]) { acc, wrapper in
                let accounts = try wrapper.targetOperation.extractNoCancellableResultData()

                accounts.forEach {
                    if let delegatedAccounts = acc[$0.key] {
                        acc[$0.key] = delegatedAccounts + $0.value
                    } else {
                        acc[$0.key] = $0.value
                    }
                }
            }
        }

        fetchWrappers.forEach {
            mapOperation.addDependency($0.targetOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: fetchWrappers.flatMap(\.allOperations)
        )
    }

    func createDiscoverAccountsWrapper(
        delegatedAccountsSources: [DelegatedAccountsRepositoryProtocol],
        discoveringAccountIds: DiscoveringAccountIds
    ) -> CompoundOperationWrapper<[AccountId: [DelegatedAccountProtocol]]> {
        let accountsFetchWrapper = createAccountsFetchWrapper(
            for: delegatedAccountsSources,
            accountIds: discoveringAccountIds.possibleAccountIds
        )

        let resultWrapper: CompoundOperationWrapper<[AccountId: [DelegatedAccountProtocol]]>
        resultWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else { throw BaseOperationError.parentOperationCancelled }

            let delegatedAccounts = try accountsFetchWrapper
                .targetOperation
                .extractNoCancellableResultData()

            let discoveredAccountIds: Set<AccountId> = Set(
                delegatedAccounts.values
                    .flatMap { $0 }
                    .compactMap(\.accountId)
                    + delegatedAccounts.keys
            )

            let updatedDiscoveringIds = DiscoveringAccountIds(
                possibleAccountIds: discoveringAccountIds.possibleAccountIds.union(discoveredAccountIds),
                knownAccountIds: discoveringAccountIds.possibleAccountIds,
                discoveredAccounts: delegatedAccounts
            )

            guard updatedDiscoveringIds.possibleAccountIds != updatedDiscoveringIds.knownAccountIds else {
                return .createWithResult(updatedDiscoveringIds.discoveredAccounts)
            }

            return createDiscoverAccountsWrapper(
                delegatedAccountsSources: delegatedAccountsSources,
                discoveringAccountIds: updatedDiscoveringIds
            )
        }

        resultWrapper.addDependency(wrapper: accountsFetchWrapper)

        return resultWrapper.insertingHead(operations: accountsFetchWrapper.allOperations)
    }

    func createChangesWrapper(
        delegatedAccountsListWrapper: CompoundOperationWrapper<[AccountId: [DelegatedAccountProtocol]]>,
        metaAccountsWrapper: CompoundOperationWrapper<[ManagedMetaAccountModel]>,
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) -> CompoundOperationWrapper<SyncChanges<ManagedMetaAccountModel>> {
        let identityWrapper = identityProxyFactory.createIdentityWrapperByAccountId(
            for: {
                let delegatedAccounts = try delegatedAccountsListWrapper
                    .targetOperation
                    .extractNoCancellableResultData()

                let delegatorIds = delegatedAccounts
                    .map(\.key)
                let delegatedIds = delegatedAccounts
                    .flatMap(\.value)
                    .compactMap(\.accountId)

                return delegatorIds + delegatedIds
            }
        )

        identityWrapper.addDependency(wrapper: delegatedAccountsListWrapper)

        let mapOperation = ClosureOperation<SyncChanges<ManagedMetaAccountModel>> { [changesCalculator] in
            let identities = try identityWrapper.targetOperation.extractNoCancellableResultData()
            let chainMetaAccounts = try metaAccountsWrapper.targetOperation.extractNoCancellableResultData()
            let remoteDelegatedAccounts = try delegatedAccountsListWrapper
                .targetOperation.extractNoCancellableResultData()

            return try changesCalculator.calculateUpdates(
                from: remoteDelegatedAccounts,
                chainMetaAccounts: chainMetaAccounts,
                identities: identities
            )
        }

        mapOperation.addDependency(identityWrapper.targetOperation)
        mapOperation.addDependency(metaAccountsWrapper.targetOperation)
        mapOperation.addDependency(delegatedAccountsListWrapper.targetOperation)

        let dependencies = delegatedAccountsListWrapper.allOperations + identityWrapper.allOperations

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
