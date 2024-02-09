import Foundation
import SubstrateSdk
import RobinHood

final class HydraStableswapQuoteParamsService: ObservableSyncService, ObservableSubscriptionSyncServiceProtocol {
    typealias TState = HydraStableswap.QuoteParams

    let userAccountId: AccountId
    let poolAsset: HydraDx.AssetId
    let assetIn: HydraDx.AssetId
    let assetOut: HydraDx.AssetId
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let repository: AnyDataProviderRepository<ChainStorageItem>?
    let workQueue: DispatchQueue

    private var poolService: HydraStableswapPoolService?
    private var reservesService: HydraStableswapReservesService?

    init(
        userAccountId: AccountId,
        poolAsset: HydraDx.AssetId,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<ChainStorageItem>? = nil,
        workQueue: DispatchQueue = .global(),
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.userAccountId = userAccountId
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

    private func clearServices() {
        poolService?.throttle()
        poolService = nil

        reservesService?.throttle()
        reservesService = nil
    }

    private func updateIsSyncing() {
        let poolSyncing = poolService?.getIsSyncing() ?? true
        let reservesSyncing = reservesService?.getIsSyncing() ?? true

        isSyncing = poolSyncing || reservesSyncing
    }

    private func setupReservesServiceIfNeeded() {
        guard reservesService == nil, let poolInfo = poolService?.getState()?.poolInfo else {
            return
        }

        reservesService = .init(
            userAccountId: userAccountId,
            poolAsset: poolAsset,
            otherAssets: poolInfo.assets.map(\.value),
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

    override func performSyncUp() {
        clearServices()

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

            self?.setupReservesServiceIfNeeded()
        }

        poolService?.setup()
    }

    override func stopSyncUp() {
        clearServices()
    }

    func getState() -> HydraStableswap.QuoteParams? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let poolInfo = poolService?.getState(), let reserves = reservesService?.getState() {
            return .init(poolInfo: poolInfo, reserves: reserves)
        } else {
            return nil
        }
    }
}
