import Foundation
import Operation_iOS
import SubstrateSdk

final class NominationPoolsAccountUpdatingService: BaseSyncService, NPoolsLocalStorageSubscriber,
    RuntimeConstantFetching {
    let accountId: AccountId
    let chainAsset: ChainAsset
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let cacheRepository: AnyDataProviderRepository<ChainStorageItem>
    let remoteSubscriptionService: NominationPoolsPoolSubscriptionServiceProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue

    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var remoteSubscriptionId: UUID?
    private var poolId: NominationPools.PoolId?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        cacheRepository: AnyDataProviderRepository<ChainStorageItem>,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        remoteSubscriptionService: NominationPoolsPoolSubscriptionServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.connection = connection
        self.runtimeService = runtimeService
        self.cacheRepository = cacheRepository
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.remoteSubscriptionService = remoteSubscriptionService
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    deinit {
        clearSubscriptions()
    }

    override func performSyncUp() {
        clearLocalSubscription()

        poolMemberProvider = subscribePoolMember(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            callbackQueue: DispatchQueue.global(qos: .userInitiated)
        )

        if poolMemberProvider == nil {
            completeImmediate(CommonError.databaseSubscription)
        }
    }

    override func stopSyncUp() {
        clearSubscriptions()
    }

    private func clearSubscriptions() {
        clearLocalSubscription()
        clearRemoteSubscription()
    }

    private func clearLocalSubscription() {
        poolMemberProvider = nil
    }

    private func clearRemoteSubscription() {
        if let remoteSubscriptionId = remoteSubscriptionId, let poolId = poolId {
            remoteSubscriptionService.detachFromPoolData(
                for: remoteSubscriptionId,
                chainId: chainAsset.chain.chainId,
                poolId: poolId,
                queue: nil,
                closure: nil
            )

            self.remoteSubscriptionId = nil
        }
    }

    private func subscribeRemote(for poolId: NominationPools.PoolId) {
        remoteSubscriptionId = remoteSubscriptionService.attachToPoolData(
            for: chainAsset.chain.chainId,
            poolId: poolId,
            queue: .global(qos: .userInitiated)
        ) { [weak self] result in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            switch result {
            case .success:
                self?.logger.debug("Subscribe for remote pool: \(poolId)")
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.logger.error("Couldn't subscribe remote: \(error)")
                self?.completeImmediate(error)
            }
        }
    }
}

extension NominationPoolsAccountUpdatingService: NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        markSyncingImmediate()

        clearRemoteSubscription()

        switch result {
        case let .success(optPoolMember):
            poolId = optPoolMember?.poolId

            if let poolMember = optPoolMember {
                logger.debug("Did receive pool member: \(poolMember)")

                subscribeRemote(for: poolMember.poolId)
            } else {
                logger.warning("No pool staking found")
            }
        case let .failure(error):
            logger.error("Local subscription error: \(error)")

            completeImmediate(error)
        }
    }
}

protocol NominationPoolsAccountUpdatingFactoryProtocol {
    func create(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> NominationPoolsAccountUpdatingService
}

final class NominationPoolsAccountUpdatingFactory: NominationPoolsAccountUpdatingFactoryProtocol {
    let chainRegistry: ChainRegistryProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let remoteSubscriptionService: NominationPoolsPoolSubscriptionServiceProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        chainRegistry: ChainRegistryProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        remoteSubscriptionService: NominationPoolsPoolSubscriptionServiceProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.repositoryFactory = repositoryFactory
        self.remoteSubscriptionService = remoteSubscriptionService
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }

    func create(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) throws -> NominationPoolsAccountUpdatingService {
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }

        return .init(
            accountId: accountId,
            chainAsset: chainAsset,
            connection: connection,
            runtimeService: runtimeService,
            cacheRepository: repositoryFactory.createChainStorageItemRepository(),
            npoolsLocalSubscriptionFactory: npoolsLocalSubscriptionFactory,
            remoteSubscriptionService: remoteSubscriptionService,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}
