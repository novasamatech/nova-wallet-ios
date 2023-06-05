import Foundation
import RobinHood
import SubstrateSdk

protocol MultistakingSyncServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class MultistakingSyncService {
    typealias OnchainSyncServiceProtocol = ObservableSyncServiceProtocol & ApplicationServiceProtocol

    let chainRegistry: ChainRegistryProtocol
    let repositoryFactory: MultistakingRepositoryFactoryProtocol
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
        repositoryFactory: MultistakingRepositoryFactoryProtocol,
        offchainOperationFactory: MultistakingOffchainOperationFactoryProtocol,
        operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue,
        workingQueue: DispatchQueue = .global(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.providerFactory = providerFactory
        self.repositoryFactory = repositoryFactory
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
            runningInQueue: workingQueue
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
        let dashboardRepository = repositoryFactory.createOffchainRepository()

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

    private func createOnchainService(for chainAssetOption: Multistaking.ChainAssetOption) {
        let stakingOption = chainAssetOption.option

        switch chainAssetOption.type {
        case .relaychain, .azero, .auraRelaychain:
            if let service = createRelaychainStaking(
                for: chainAssetOption.chainAsset,
                stakingType: chainAssetOption.type
            ) {
                onchainUpdaters[stakingOption] = service

                addSyncHandler(for: service, stakingOption: stakingOption)

                if isActive {
                    service.setup()
                }
            }
        case .parachain, .turing:
            if let service = createParachainStaking(
                for: chainAssetOption.chainAsset,
                stakingType: chainAssetOption.type
            ) {
                onchainUpdaters[stakingOption] = service

                addSyncHandler(for: service, stakingOption: stakingOption)

                if isActive {
                    service.setup()
                }
            }
        case .unsupported:
            logger.warning("Trying to create service for unsupported staking")
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
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        return RelaychainMultistakingUpdateService(
            walletId: wallet.metaId,
            accountId: account.accountId,
            chainAsset: chainAsset,
            stakingType: stakingType,
            dashboardRepository: repositoryFactory.createRelaychainRepository(),
            accountRepository: repositoryFactory.createResolvedAccountRepository(),
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

        let operationFactory = ParaStkCollatorsOperationFactory(
            requestFactory: requestFactory,
            identityOperationFactory: identityFactory
        )

        return ParachainMultistakingUpdateService(
            walletId: wallet.metaId,
            accountId: account.accountId,
            chainAsset: chainAsset,
            stakingType: stakingType,
            dashboardRepository: repositoryFactory.createParachainRepository(),
            connection: connection,
            runtimeService: runtimeService,
            operationFactory: operationFactory,
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
}
