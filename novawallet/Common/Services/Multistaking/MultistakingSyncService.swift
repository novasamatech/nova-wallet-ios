import Foundation
import RobinHood
import SubstrateSdk

protocol MultistakingSyncServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class MultistakingSyncService {
    let chainRegistry: ChainRegistryProtocol
    let repositoryFactory: MultistakingRepositoryFactoryProtocol
    let providerFactory: MultistakingProviderFactoryProtocol
    let offchainOperationFactory: MultistakingOffchainOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var wallet: MetaAccountModel

    private(set) var isActive: Bool = false

    private(set) var onchainUpdaters: [Multistaking.Option: ApplicationServiceProtocol] = [:]
    private(set) var offchainUpdater: OffchainMultistakingUpdateServiceProtocol?

    private let mutex = NSLock()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        providerFactory: MultistakingProviderFactoryProtocol,
        repositoryFactory: MultistakingRepositoryFactoryProtocol,
        offchainOperationFactory: MultistakingOffchainOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.providerFactory = providerFactory
        self.repositoryFactory = repositoryFactory
        self.offchainOperationFactory = offchainOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger

        setupOffchainService()
        subscribeChains()
    }

    private func subscribeChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .global()
        ) { [weak self] changes in
            self?.mutex.lock()

            self?.handleChain(changes: changes)

            self?.mutex.unlock()
        }
    }

    private func handleChain(changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(newItem):
                setupOnchainServices(for: newItem)
            case let .update(newItem):
                updateOnchainServices(for: newItem)
            case let .delete(deletedIdentifier):
                removeOnchainServices(for: deletedIdentifier)
            }
        }
    }

    private func setupOffchainService() {
        let accountProvider = providerFactory.createResolvedAccountsProvider()
        let dashboardRepository = repositoryFactory.createOffchainRepository()

        offchainUpdater = OffchainMultistakingUpdateService(
            wallet: wallet,
            accountResolveProvider: accountProvider,
            dashboardRepository: dashboardRepository,
            operationFactory: offchainOperationFactory,
            workingQueue: .global(),
            operationQueue: operationQueue
        )

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
    ) -> ApplicationServiceProtocol? {
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
            workingQueue: .global(),
            logger: logger
        )
    }

    private func createParachainStaking(
        for chainAsset: ChainAsset,
        stakingType: StakingType
    ) -> ApplicationServiceProtocol? {
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
            workingQueue: .global(),
            logger: logger
        )
    }

    private func throttleOnchainServices() {
        onchainUpdaters.values.forEach {
            $0.throttle()
        }
    }
}

extension MultistakingSyncService: MultistakingSyncServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        wallet = selectedMetaAccount

        offchainUpdater?.throttle()
        offchainUpdater = nil

        throttleOnchainServices()
        onchainUpdaters = [:]

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
}
