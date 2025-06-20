import Foundation
import Operation_iOS
import SubstrateSdk

protocol MultistakingSyncServiceProtocol: ApplicationServiceProtocol {
    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (MultistakingSyncState, MultistakingSyncState) -> Void
    )

    func unsubscribeSyncState(_ target: AnyObject)

    func update(selectedMetaAccount: MetaAccountModel)

    func refreshOffchain()
}

final class MultistakingSyncService {
    typealias OnchainSyncServiceProtocol = ObservableSyncServiceProtocol & ApplicationServiceProtocol

    let chainRegistry: ChainRegistryProtocol
    let multistakingRepositoryFactory: MultistakingRepositoryFactoryProtocol
    let substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol
    let providerFactory: MultistakingProviderFactoryProtocol
    let offchainOperationFactory: MultistakingOffchainOperationFactoryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue
    let logger: LoggerProtocol

    private var wallet: MetaAccountModel

    private(set) var isActive: Bool = false

    private(set) var onchainUpdaters: [Multistaking.Option: OnchainSyncServiceProtocol] = [:]
    private(set) var offchainUpdater: OffchainMultistakingUpdateServiceProtocol?
    private(set) var stakableChainAssets: Set<ChainAsset> = []

    private let mutex = NSLock()

    private var stateObserver = Observable<MultistakingSyncState>(state: .init())

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        providerFactory: MultistakingProviderFactoryProtocol,
        multistakingRepositoryFactory: MultistakingRepositoryFactoryProtocol,
        substrateRepositoryFactory: SubstrateRepositoryFactoryProtocol,
        offchainOperationFactory: MultistakingOffchainOperationFactoryProtocol,
        operationQueue: OperationQueue = OperationManagerFacade.assetsRepositoryQueue,
        workingQueue: DispatchQueue = DispatchQueue(
            label: "com.nova.wallet.staking.sync",
            qos: .userInitiated,
            attributes: .concurrent
        ),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.providerFactory = providerFactory
        self.multistakingRepositoryFactory = multistakingRepositoryFactory
        self.substrateRepositoryFactory = substrateRepositoryFactory
        self.offchainOperationFactory = offchainOperationFactory
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue
        self.logger = logger

        setupOffchainService()
        subscribeChains()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: workingQueue,
            filterStrategy: .enabledChains
        ) { [weak self] changes in
            guard let self = self else {
                return
            }

            self.mutex.lock()

            let stakableChainAssets = self.handleChain(changes: changes)

            self.mutex.unlock()

            self.offchainUpdater?.apply(newChainAssets: stakableChainAssets)
        }
    }

    private func handleChain(changes: [DataProviderChange<ChainModel>]) -> Set<ChainAsset> {
        changes.forEach { change in
            switch change {
            case let .insert(newItem):
                setupOnchainServices(for: newItem)

                let newChainAssets = newItem.getAllStakingChainAssetOptions().map(\.chainAsset)
                stakableChainAssets.formUnion(newChainAssets)
            case let .update(newItem):
                updateOnchainServices(for: newItem)

                let newChainAssets = newItem.getAllStakingChainAssetOptions().map(\.chainAsset)
                stakableChainAssets.formUnion(newChainAssets)
            case let .delete(deletedIdentifier):
                removeOnchainServices(for: deletedIdentifier)

                stakableChainAssets = stakableChainAssets.filter { $0.chain.chainId != deletedIdentifier }
            }
        }

        return stakableChainAssets
    }

    private func setupOffchainService() {
        let accountProvider = providerFactory.createResolvedAccountsProvider()
        let dashboardRepository = multistakingRepositoryFactory.createOffchainRepository()

        offchainUpdater = OffchainMultistakingUpdateService(
            wallet: wallet,
            accountResolveProvider: accountProvider,
            dashboardRepository: dashboardRepository,
            operationFactory: offchainOperationFactory,
            workingQueue: workingQueue,
            operationQueue: operationQueue
        )

        offchainUpdater?.subscribeSyncState(
            self,
            queue: workingQueue
        ) { [weak self] _, isSyncing in
            guard let self = self else {
                return
            }

            self.mutex.lock()

            self.stateObserver.state = self.stateObserver.state.updating(isOffchainSyncing: isSyncing)

            self.mutex.unlock()
        }

        if isActive {
            offchainUpdater?.setup()
        }
    }

    private func setupOnchainServices(for chain: ChainModel) {
        chain.getAllStakingChainAssetOptions().forEach { chainAssetOption in
            createOnchainService(for: chainAssetOption)
        }
    }

    private func updateOnchainServices(for chain: ChainModel) {
        let updatedChainAssetOptions = chain.getAllStakingChainAssetOptions()
        let currentStakingOptions = Set(onchainUpdaters.keys).filter {
            $0.chainAssetId.chainId == chain.chainId
        }

        let newOptions = updatedChainAssetOptions.filter {
            !currentStakingOptions.contains($0.option)
        }

        let updatedStakingOptions = Set(updatedChainAssetOptions.map(\.option))

        let removedOptions = currentStakingOptions.filter { !updatedStakingOptions.contains($0) }

        newOptions.forEach { chainAssetOption in
            createOnchainService(for: chainAssetOption)
        }

        removedOptions.forEach { stakingOption in
            removeOnchainService(for: stakingOption)
        }
    }

    private func removeOnchainServices(for chainId: ChainModel.Id) {
        let removingStakingOptions = onchainUpdaters.keys.filter {
            $0.chainAssetId.chainId == chainId
        }

        removingStakingOptions.forEach { stakingOption in
            removeOnchainService(for: stakingOption)
        }
    }

    private func makeOnchainService(
        for chainAssetOption: Multistaking.ChainAssetOption
    ) -> OnchainSyncServiceProtocol? {
        switch chainAssetOption.type {
        case .relaychain, .azero, .auraRelaychain:
            createRelaychainStaking(
                for: chainAssetOption.chainAsset,
                stakingType: chainAssetOption.type
            )
        case .parachain, .turing:
            createParachainStaking(
                for: chainAssetOption.chainAsset,
                stakingType: chainAssetOption.type
            )
        case .nominationPools:
            createPoolsStaking(
                for: chainAssetOption.chainAsset,
                stakingType: chainAssetOption.type
            )
        case .mythos:
            createMythosStaking(
                for: chainAssetOption.chainAsset,
                stakingType: chainAssetOption.type
            )
        case .unsupported:
            nil
        }
    }

    private func createOnchainService(for chainAssetOption: Multistaking.ChainAssetOption) {
        guard let service = makeOnchainService(for: chainAssetOption) else {
            logger.warning("Trying to create service for unsupported staking")
            return
        }

        let stakingOption = chainAssetOption.option
        onchainUpdaters[stakingOption] = service

        addSyncHandler(for: service, stakingOption: stakingOption)

        if isActive {
            service.setup()
        }
    }

    private func removeOnchainService(for stakingOption: Multistaking.Option) {
        let service = onchainUpdaters[stakingOption]
        onchainUpdaters[stakingOption] = nil
        service?.throttle()
    }

    private func createRelaychainStaking(
        for chainAsset: ChainAsset,
        stakingType: StakingType
    ) -> OnchainSyncServiceProtocol? {
        guard
            let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountAddress = try? account.accountId.toAddress(using: chainAsset.chain.chainFormat) else {
            return nil
        }

        let stashItemRepository = substrateRepositoryFactory.createStashItemRepository(
            for: accountAddress, chainId: chainAsset.chain.chainId
        )

        return RelaychainMultistakingUpdateService(
            walletId: wallet.metaId,
            accountId: account.accountId,
            chainAsset: chainAsset,
            stakingType: stakingType,
            dashboardRepository: multistakingRepositoryFactory.createRelaychainRepository(),
            accountRepository: multistakingRepositoryFactory.createResolvedAccountRepository(),
            cacheRepository: substrateRepositoryFactory.createChainStorageItemRepository(),
            stashItemRepository: stashItemRepository,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )
    }

    private func createPoolsStaking(
        for chainAsset: ChainAsset,
        stakingType: StakingType
    ) -> OnchainSyncServiceProtocol? {
        guard
            let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        return PoolsMultistakingUpdateService(
            walletId: wallet.metaId,
            accountId: account.accountId,
            chainAsset: chainAsset,
            stakingType: stakingType,
            dashboardRepository: multistakingRepositoryFactory.createNominationPoolsRepository(),
            accountRepository: multistakingRepositoryFactory.createResolvedAccountRepository(),
            cacheRepository: substrateRepositoryFactory.createChainStorageItemRepository(),
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )
    }

    private func createParachainStaking(
        for chainAsset: ChainAsset,
        stakingType: StakingType
    ) -> OnchainSyncServiceProtocol? {
        guard
            let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: operationQueue)
        )

        let identityFactory = IdentityOperationFactory(
            requestFactory: requestFactory,
            emptyIdentitiesWhenNoStorage: true
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: identityFactory
        )

        let operationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: requestFactory,
            connection: connection,
            runtimeProvider: runtimeService,
            identityFactory: identityProxyFactory,
            chainFormat: chainAsset.chain.chainFormat
        )

        return ParachainMultistakingUpdateService(
            walletId: wallet.metaId,
            accountId: account.accountId,
            chainAsset: chainAsset,
            stakingType: stakingType,
            dashboardRepository: multistakingRepositoryFactory.createParachainRepository(),
            cacheRepository: substrateRepositoryFactory.createChainStorageItemRepository(),
            connection: connection,
            runtimeService: runtimeService,
            operationFactory: operationFactory,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )
    }

    private func createMythosStaking(
        for chainAsset: ChainAsset,
        stakingType: StakingType
    ) -> OnchainSyncServiceProtocol? {
        guard
            let account = wallet.fetch(for: chainAsset.chain.accountRequest()),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let collatorsOperationFactory = MythosCollatorOperationFactory(
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            timeout: JSONRPCTimeout.hour
        )

        return MythosMultistakingUpdateService(
            walletId: wallet.metaId,
            accountId: account.accountId,
            chainAsset: chainAsset,
            stakingType: stakingType,
            dashboardRepository: multistakingRepositoryFactory.createMythosRepository(),
            collatorsOperationFactory: collatorsOperationFactory,
            cacheRepository: substrateRepositoryFactory.createChainStorageItemRepository(),
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: operationQueue,
            workingQueue: workingQueue,
            logger: logger
        )
    }

    private func throttleOnchainServices() {
        onchainUpdaters.values.forEach {
            $0.throttle()
        }
    }

    private func removeOnchainSyncHandler() {
        onchainUpdaters.values.forEach { $0.unsubscribeSyncState(self) }
    }

    private func addSyncHandler(for service: ObservableSyncServiceProtocol, stakingOption: Multistaking.Option) {
        service.subscribeSyncState(
            self,
            queue: workingQueue
        ) { [weak self] _, isSyncing in
            guard let self = self else {
                return
            }

            self.mutex.lock()

            self.stateObserver.state = self.stateObserver.state.updating(
                syncing: isSyncing,
                stakingOption: stakingOption
            )

            self.mutex.unlock()
        }
    }

    private func updateSyncState() {
        let onchainSyncState = onchainUpdaters.mapValues { $0.getIsSyncing() }
        let offchainSyncState = offchainUpdater?.getIsSyncing() ?? false

        let newState = MultistakingSyncState(
            isOnchainSyncing: onchainSyncState,
            isOffchainSyncing: offchainSyncState
        )

        stateObserver.state = newState
    }
}

extension MultistakingSyncService: MultistakingSyncServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        wallet = selectedMetaAccount

        offchainUpdater?.unsubscribeSyncState(self)
        offchainUpdater?.throttle()
        offchainUpdater = nil

        removeOnchainSyncHandler()
        throttleOnchainServices()
        onchainUpdaters = [:]

        stateObserver.state = .init()

        chainRegistry.chainsUnsubscribe(self)

        setupOffchainService()
        subscribeChains()
    }

    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard !isActive else {
            return
        }

        isActive = true

        offchainUpdater?.setup()

        onchainUpdaters.values.forEach { onchainUpdater in
            onchainUpdater.setup()
        }
    }

    func throttle() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard isActive else {
            return
        }

        isActive = false

        offchainUpdater?.throttle()

        throttleOnchainServices()
    }

    func subscribeSyncState(
        _ target: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (MultistakingSyncState, MultistakingSyncState) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let state = stateObserver.state

        dispatchInQueueWhenPossible(queue) {
            closure(state, state)
        }

        stateObserver.addObserver(with: target, queue: queue, closure: closure)
    }

    func unsubscribeSyncState(_ target: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObserver.removeObserver(by: target)
    }

    func refreshOffchain() {
        offchainUpdater?.syncUp()
    }
}
