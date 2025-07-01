import Foundation
import SubstrateSdk
import BigInt

final class EvmNativeSubscriptionManager {
    let chainId: ChainModel.Id
    let params: EvmNativeBalanceSubscriptionRequest
    let connection: JSONRPCEngine
    let logger: LoggerProtocol?
    let serviceFactory: EvmBalanceUpdateServiceFactoryProtocol
    let eventCenter: EventCenterProtocol?

    private var syncService: SyncServiceProtocol?

    @Atomic(defaultValue: nil) private var subscriptionId: UInt16?

    private let logProcessMutex = NSLock()

    private var processingBlockNumber: BigUInt?

    init(
        chainId: ChainModel.Id,
        params: EvmNativeBalanceSubscriptionRequest,
        serviceFactory: EvmBalanceUpdateServiceFactoryProtocol,
        connection: JSONRPCEngine,
        eventCenter: EventCenterProtocol?,
        logger: LoggerProtocol?
    ) {
        self.chainId = chainId
        self.params = params
        self.serviceFactory = serviceFactory
        self.connection = connection
        self.eventCenter = eventCenter
        self.logger = logger
    }

    deinit {
        unsubscribe()
    }

    private func handleTransactionsIfNeeded(for blockNumber: BigUInt) {
        params.transactionHistoryUpdater?.processEvmNativeTransactions(from: blockNumber)
    }

    private func notifyBalanceUpdateIfNeeded() {
        guard let eventCenter else {
            return
        }

        guard let accountId = try? params.holder.toAccountId(using: .ethereum) else {
            return
        }

        let event = AssetBalanceChanged(
            chainAssetId: ChainAssetId(chainId: chainId, assetId: params.assetId),
            accountId: accountId,
            changes: nil,
            block: nil
        )

        eventCenter.notify(with: event)
    }

    private func processBlock(_ blockNumber: BigUInt) {
        logProcessMutex.lock()

        defer {
            logProcessMutex.unlock()
        }

        processingBlockNumber = blockNumber
        syncService?.stopSyncUp()
        syncService = nil

        do {
            let block = EvmBalanceUpdateBlock(
                updateDetectedAt: .exact(blockNumber),
                fetchRequestedAt: .latest
            )

            syncService = try serviceFactory.createNativeBalanceUpdateService(
                for: params.holder,
                chainAssetId: .init(chainId: chainId, assetId: params.assetId),
                block: block
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
                    self?.notifyBalanceUpdateIfNeeded()
                    self?.handleTransactionsIfNeeded(for: blockNumber)
                }
            }

            syncService?.setup()
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
                unsubscribeMethod: EvmSubscriptionMessage.unsubscribeMethod,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            logger?.debug("Did create evm native balance subscription: \(params.holder) \(chainId)")
        } catch {
            logger?.error("Can't create evm subscription: \(chainId)")
        }
    }

    private func unsubscribe() {
        syncService?.stopSyncUp()

        if let subscriptionId = subscriptionId {
            connection.cancelForIdentifier(subscriptionId)
        }
    }

    private func subscribe() throws {
        let block = EvmBalanceUpdateBlock(updateDetectedAt: nil, fetchRequestedAt: .latest)
        syncService = try serviceFactory.createNativeBalanceUpdateService(
            for: params.holder,
            chainAssetId: .init(chainId: chainId, assetId: params.assetId),
            block: block
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

    func stop() throws {
        unsubscribe()
    }
}
