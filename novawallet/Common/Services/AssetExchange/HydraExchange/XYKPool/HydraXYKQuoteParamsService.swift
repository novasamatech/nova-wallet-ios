import Foundation
import SubstrateSdk
import Operation_iOS

final class HydraXYKQuoteParamsService: ObservableSyncService {
    typealias TState = HydraXYK.QuoteRemoteState

    let chain: ChainModel
    let assetIn: HydraDx.AssetId
    let assetOut: HydraDx.AssetId
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeProviderProtocol
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private var balanceSyncer: HydraBalanceSyncer?
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
        self.operationQueue = operationQueue
        self.workQueue = workQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        guard balanceSyncer == nil else {
            return
        }

        do {
            let poolAccountId = try HydraXYK.deriveAccount(from: assetIn, asset2: assetOut)
            self.poolAccountId = poolAccountId

            let syncer = HydraBalanceSyncer(
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

            balanceSyncer = syncer

            syncer.setup()

            syncer.subscribeSyncState(
                self,
                queue: workQueue
            ) { [weak self] _, isSyncing in
                guard let self else { return }

                mutex.lock()

                defer {
                    mutex.unlock()
                }

                self.isSyncing = isSyncing
            }
        } catch {
            logger.error("Unexpected error: \(error)")
        }
    }

    override func stopSyncUp() {
        balanceSyncer?.throttle()
        balanceSyncer = nil
    }
}

extension HydraXYKQuoteParamsService: ObservableSubscriptionSyncServiceProtocol {
    func getState() -> TState? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard
            let balanceState = balanceSyncer?.getBalancesState(),
            let poolAccountId else {
            return nil
        }

        let accountAssetIn = HydraAccountAsset(accountId: poolAccountId, assetId: assetIn)
        let accountAssetOut = HydraAccountAsset(accountId: poolAccountId, assetId: assetOut)

        guard
            let balanceIn = balanceState[accountAssetIn],
            let balanceOut = balanceState[accountAssetOut] else {
            return nil
        }

        return TState(
            assetInBalance: balanceIn.free,
            assetOutBalance: balanceOut.free
        )
    }
}
