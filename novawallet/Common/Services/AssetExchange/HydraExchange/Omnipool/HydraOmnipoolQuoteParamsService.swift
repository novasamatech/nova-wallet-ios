import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraOmnipoolQuoteParamsService: ObservableSyncService, ObservableSubscriptionSyncServiceProtocol {
    typealias TState = HydraOmnipool.QuoteRemoteState

    let chain: ChainModel
    let assetIn: HydraDx.AssetId
    let assetOut: HydraDx.AssetId
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private var assetFeeService: HydraOmnipoolAssetsFeeService?
    private var balanceService: HydraBalanceSyncer?
    private var poolAccountId: AccountId?

    init(
        chain: ChainModel,
        assetIn: HydraDx.AssetId,
        assetOut: HydraDx.AssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.chain = chain
        self.assetIn = assetIn
        self.assetOut = assetOut
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.workQueue = workQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearServices()

        setupAssetFeeServiceIfNeeded()
        setupBalanceServiceIfNeeded()
    }

    override func stopSyncUp() {
        clearServices()
    }

    func getState() -> TState? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard
            let assetFeeState = assetFeeService?.getState(),
            let balanceState = balanceService?.getBalancesState(),
            let poolAccountId
        else {
            return nil
        }

        let accountAssetIn = HydraAccountAsset(accountId: poolAccountId, assetId: assetIn)
        let accountAssetOut = HydraAccountAsset(accountId: poolAccountId, assetId: assetOut)

        guard
            let balanceIn = balanceState[accountAssetIn],
            let balanceOut = balanceState[accountAssetOut] else {
            return nil
        }

        return .init(
            assetInState: assetFeeState.assetInState,
            assetOutState: assetFeeState.assetOutState,
            assetInBalance: balanceIn.free,
            assetOutBalance: balanceOut.free,
            assetInFee: assetFeeState.assetInFee,
            assetOutFee: assetFeeState.assetOutFee,
            blockHash: assetFeeState.blockHash
        )
    }
}

private extension HydraOmnipoolQuoteParamsService {
    func updateIsSyncing() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let assetsFeeSyncing = assetFeeService?.getIsSyncing() ?? true
        let balancesSyncing = balanceService?.getIsSyncing() ?? true

        isSyncing = assetsFeeSyncing || balancesSyncing
    }

    func setupAssetFeeServiceIfNeeded() {
        guard assetFeeService == nil else {
            return
        }

        assetFeeService = HydraOmnipoolAssetsFeeService(
            chain: chain,
            assetIn: assetIn,
            assetOut: assetOut,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            workQueue: workQueue,
            logger: logger
        )

        assetFeeService?.subscribeSyncState(
            self,
            queue: workQueue
        ) { [weak self] _, _ in
            self?.updateIsSyncing()
        }

        assetFeeService?.setup()
    }

    func setupBalanceServiceIfNeeded() {
        guard balanceService == nil else {
            return
        }

        do {
            let poolAccountId = try HydraOmnipool.getPoolAccountId(for: chain.accountIdSize)
            self.poolAccountId = poolAccountId

            balanceService = HydraBalanceSyncer(
                accountAssets: [
                    HydraAccountAsset(accountId: poolAccountId, assetId: assetIn),
                    HydraAccountAsset(accountId: poolAccountId, assetId: assetOut)
                ],
                runtimeProvider: runtimeProvider,
                connection: connection,
                operationQueue: operationQueue,
                workQueue: workQueue,
                logger: logger
            )

            balanceService?.subscribeSyncState(
                self,
                queue: workQueue
            ) { [weak self] _, _ in
                self?.updateIsSyncing()
            }

            balanceService?.setup()
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }

    func clearServices() {
        assetFeeService?.throttle()
        assetFeeService = nil

        balanceService?.throttle()
        balanceService = nil
    }
}
