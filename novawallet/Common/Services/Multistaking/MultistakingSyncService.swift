import Foundation
import RobinHood

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

    @Atomic(defaultValue: false) var isActive: Bool

    @Atomic(defaultValue: [:]) var onchainUpdaters: [Multistaking.Option: ApplicationServiceProtocol]
    @Atomic(defaultValue: nil) var offchainUpdater: OffchainMultistakingUpdateServiceProtocol?

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
            runningInQueue: .global(qos: .default)
        ) { [weak self] changes in
            self?.handleChain(changes: changes)
        }
    }

    private func handleChain(changes: [DataProviderChange<ChainModel>]) {

    }

    private func setupOffchainService() {
        let accountProvider = providerFactory.createResolvedAccountsProvider()
        let dashboardRepository = repositoryFactory.createOffchainRepository()

        offchainUpdater = OffchainMultistakingUpdateService(
            wallet: wallet,
            accountResolveProvider: accountProvider,
            dashboardRepository: dashboardRepository,
            operationFactory: offchainOperationFactory,
            operationQueue: operationQueue
        )

        if isActive {
            offchainUpdater?.setup()
        }
    }

    private func setupOnchainServices(for chain: ChainModel) {
        chain.assets.forEach { asset in
            asset.stakings?.forEach { stakingType in
                let stakingOption = Multistaking.Option(
                    chainAssetId: .init(chainId: chain.chainId, assetId: asset.assetId),
                    type: stakingType
                )

                switch stakingType {
                case .relaychain, .azero, .auraRelaychain:
                    if let service = createRelaychainStaking(
                        for: ChainAsset(chain: chain, asset: asset),
                        stakingType: stakingType
                    ) {
                        onchainUpdaters[stakingOption] = service

                        if isActive {
                            service.setup()
                        }
                    }
                case .parachain, .turing:
                    return
                case .unsupported:
                    return
                }
            }
        }
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
        self.wallet = selectedMetaAccount

        offchainUpdater?.throttle()
        offchainUpdater = nil

        throttleOnchainServices()
        onchainUpdaters = [:]

        chainRegistry.chainsUnsubscribe(self)

        setupOffchainService()
        subscribeChains()
    }

    func setup() {
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
        guard isActive else {
            return
        }

        isActive = false

        offchainUpdater?.throttle()

        throttleOnchainServices()
    }
}
