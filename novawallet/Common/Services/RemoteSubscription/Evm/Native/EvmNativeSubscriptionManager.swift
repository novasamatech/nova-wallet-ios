import Foundation
import SubstrateSdk
import BigInt

final class EvmNativeSubscriptionManager {
    let chainId: ChainModel.Id
    let params: EvmNativeBalanceSubscriptionRequest
    let connection: JSONRPCEngine
    let logger: LoggerProtocol?
    let serviceFactory: EvmBalanceUpdateServiceFactoryProtocol
    let eventCenter: EventCenterProtocol

    private var syncService: SyncServiceProtocol?

    @Atomic(defaultValue: nil) private var subscriptionId: UInt16?

    private let logProcessMutex = NSLock()

    private var processingBlockNumber: BigUInt?

    init(
        chainId: ChainModel.Id,
        params: EvmNativeBalanceSubscriptionRequest,
        serviceFactory: EvmBalanceUpdateServiceFactoryProtocol,
        connection: JSONRPCEngine,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol?
    ) {
        self.chainId = chainId
        self.params = params
        self.serviceFactory = serviceFactory
        self.connection = connection
        self.eventCenter = eventCenter
        self.logger = logger
    }

    private func handleTransactions(for blockNumber: BigUInt) {
        params.transactionHistoryUpdater?.processEvmNativeTransactions(from: blockNumber)
    }

    private func processBlock(_ blockNumber: BigUInt) {
        logProcessMutex.lock()

        defer {
            logProcessMutex.unlock()
        }

        guard processingBlockNumber != blockNumber else {
            return
        }

        processingBlockNumber = blockNumber
        syncService?.stopSyncUp()
        syncService = nil

        do {
            syncService = try serviceFactory.createNativeBalanceUpdateService(
                for: params.holder,
                chainAssetId: .init(chainId: chainId, assetId: params.assetId),
                blockNumber: .latest
            ) { [weak self] hasChanges in
                self?.logProcessMutex.lock()

                defer {
                    self?.logProcessMutex.unlock()
                }

                guard self?.processingBlockNumber == blockNumber else {
                    return
                }

                self?.processingBlockNumber = nil
                self?.syncService = nil

                if hasChanges {
                    self?.handleTransactions(for: blockNumber)
                }
            }
        } catch {
            logger?.error("Can't create service to proccess block number: \(blockNumber.toHexString()) \(chainId)")
        }
    }

    private func performSubscription() {
        do {
            let updateClosure: (JSONRPCSubscriptionUpdate<EvmSubscriptionMessage.NewHeadsUpdate>) -> Void
            updateClosure = { [weak self] update in
                let blockNumber = update.params.result.blockNumber

                if let chainId = self?.chainId {
                    self?.logger?.debug("Did receive new evm block: \(blockNumber) \(chainId)")
                }

                self?.processBlock(blockNumber)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            subscriptionId = try connection.subscribe(
                EvmSubscriptionMessage.subscribeMethod,
                params: EvmSubscriptionMessage.NewHeadsParams(),
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            logger?.debug("Did create evm native balance subscription: \(params.holder) \(chainId)")
        } catch {
            logger?.error("Can't create evm subscription: \(chainId)")
        }
    }

    private func subscribe() throws {
        syncService = try serviceFactory.createNativeBalanceUpdateService(
            for: params.holder,
            chainAssetId: .init(chainId: chainId, assetId: params.assetId),
            blockNumber: .latest
        ) { [weak self] _ in
            self?.syncService = nil
            self?.performSubscription()
        }

        syncService?.setup()
    }
}

extension EvmNativeSubscriptionManager: EvmRemoteSubscriptionProtocol {
    func start() throws {
        try subscribe()
    }
}
