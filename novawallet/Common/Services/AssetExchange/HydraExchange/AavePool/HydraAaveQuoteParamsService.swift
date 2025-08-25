import Foundation

final class HydraAaveQuoteParamsService: ObservableSyncService {
    typealias TState = HydraAave.PoolData

    let swapPair: HydraDx.RemoteSwapPair
    let poolsService: any HydraAavePoolsServiceProtocol
    let workQueue: DispatchQueue

    private var pool: HydraAave.PoolData?

    init(
        swapPair: HydraDx.RemoteSwapPair,
        poolsService: any HydraAavePoolsServiceProtocol,
        workingQueue: DispatchQueue
    ) {
        self.swapPair = swapPair
        self.poolsService = poolsService
        workQueue = workingQueue
    }

    override func performSyncUp() {
        poolsService.remove(observer: self)

        poolsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: workQueue
        ) { [weak self] _, pools in
            guard let self, let pools else {
                return
            }

            updatePool(from: pools)
        }
    }

    override func stopSyncUp() {
        poolsService.remove(observer: self)
    }
}

private extension HydraAaveQuoteParamsService {
    func updatePool(from pools: [HydraAave.PoolData]) {
        let optNewPool = pools.first { $0.canHandleTrade(for: swapPair) }

        guard let newPool = optNewPool, pool != optNewPool else {
            completeImmediate(nil)
            return
        }

        logger.debug("New pool: \(newPool)")

        pool = newPool

        if !isSyncing {
            isSyncing = true
        }

        completeImmediate(nil)
    }
}

extension HydraAaveQuoteParamsService: ObservableSubscriptionSyncServiceProtocol {
    func getState() -> TState? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return pool
    }
}
