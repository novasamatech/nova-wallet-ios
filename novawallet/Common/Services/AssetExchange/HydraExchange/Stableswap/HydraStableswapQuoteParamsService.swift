import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraStableswapQuoteParamsService: ObservableSyncService, ObservableSubscriptionSyncServiceProtocol {
    typealias TState = HydraStableswap.QuoteParams

    let poolAsset: HydraDx.AssetId
    let assetIn: HydraDx.AssetId
    let assetOut: HydraDx.AssetId
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let repository: AnyDataProviderRepository<ChainStorageItem>?
    let workQueue: DispatchQueue

    private var poolService: HydraStableswapPoolService?
    private var reservesService: HydraStableswapReservesService?
    private var balanceSyncer: HydraBalanceSyncer?

    init(
        poolAsset: HydraDx.AssetId,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.poolAsset = poolAsset
        self.assetIn = assetIn
        self.assetOut = assetOut
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.repository = repository
        self.workQueue = workQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    override func performSyncUp() {
        clearServices()

        setupPoolServiceIfNeeded()
        setupReservesServiceIfNeeded()
    }

    override func stopSyncUp() {
        clearServices()
    }

    func getState() -> HydraStableswap.QuoteParams? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard
            let poolInfo = poolService?.getState(),
            let reserves = reservesService?.getState(),
            let balances = balanceSyncer?.getBalancesState(),
            let metadata = balanceSyncer?.getMetadataState() else {
            return nil
        }

        let assetsCount = poolInfo.poolInfo?.assets.count ?? 0

        guard
            balances.count >= assetsCount,
            metadata.count >= assetsCount else {
            return nil
        }

        let balancesByAssets = balances.reduce(into: [HydraDx.AssetId: HydraBalance]()) {
            $0[$1.key.assetId] = $1.value
        }

        return .init(
            poolInfo: poolInfo,
            reserves: reserves,
            balances: balancesByAssets,
            assetMetadata: metadata
        )
    }
}

private extension HydraStableswapQuoteParamsService {
    func clearServices() {
        poolService?.throttle()
        poolService = nil

        reservesService?.throttle()
        reservesService = nil

        balanceSyncer?.throttle()
        balanceSyncer = nil
    }

    func updateIsSyncing() {
        let poolSyncing = poolService?.getIsSyncing() ?? true
        let reservesSyncing = reservesService?.getIsSyncing() ?? true
        let balancesSyncing = balanceSyncer?.getIsSyncing() ?? true

        isSyncing = poolSyncing || reservesSyncing || balancesSyncing
    }

    func setupPoolServiceIfNeeded() {
        guard poolService == nil else {
            return
        }

        poolService = .init(
            poolAsset: poolAsset,
            assetIn: assetIn,
            assetOut: assetIn,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            repository: repository,
            workQueue: workQueue,
            retryStrategy: retryStrategy,
            logger: logger
        )

        poolService?.subscribeSyncState(
            self,
            queue: workQueue
        ) { [weak self] _, _ in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            self?.updateIsSyncing()

            self?.setupBalancesSyncerIfNeeded()
        }

        poolService?.setup()
    }

    func setupReservesServiceIfNeeded() {
        guard reservesService == nil else {
            return
        }

        reservesService = .init(
            poolAsset: poolAsset,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            repository: repository,
            workQueue: workQueue,
            retryStrategy: retryStrategy,
            logger: logger
        )

        reservesService?.subscribeSyncState(
            self,
            queue: workQueue
        ) { [weak self] _, _ in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            self?.updateIsSyncing()
        }

        reservesService?.setup()
    }

    func setupBalancesSyncerIfNeeded() {
        guard balanceSyncer == nil, let poolInfo = poolService?.getState()?.poolInfo else {
            return
        }

        do {
            let poolAccountId = try HydraStableswap.poolAccountId(for: poolAsset)

            let accountAssets = poolInfo.assets.map { asset in
                HydraAccountAsset(accountId: poolAccountId, assetId: asset.value)
            }

            balanceSyncer = HydraBalanceSyncer(
                accountAssets: Set(accountAssets),
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue,
                workQueue: workQueue,
                logger: logger
            )

            balanceSyncer?.subscribeSyncState(
                self,
                queue: workQueue
            ) { [weak self] _, _ in
                guard let self else {
                    return
                }

                mutex.lock()

                defer {
                    mutex.unlock()
                }

                updateIsSyncing()
            }

            balanceSyncer?.setup()
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }
}
