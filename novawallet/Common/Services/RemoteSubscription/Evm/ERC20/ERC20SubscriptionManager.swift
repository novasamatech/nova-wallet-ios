import Foundation
import SubstrateSdk
import web3swift
import Core
import BigInt

final class ERC20SubscriptionManager {
    let chainId: ChainModel.Id
    let params: ERC20BalanceSubscriptionRequest
    let connection: JSONRPCEngine
    let logger: LoggerProtocol?
    let serviceFactory: EvmBalanceUpdateServiceFactoryProtocol
    let eventCenter: EventCenterProtocol?

    private var syncService: SyncServiceProtocol?

    private lazy var subscriptionMessageFactory = EvmSubscriptionMessageFactory()
    @Atomic(defaultValue: nil) private var incomingSubscriptionId: UInt16?
    @Atomic(defaultValue: nil) private var outgoingSubscriptionId: UInt16?

    private var processingBlockHash: Data?

    private let logProcessMutex = NSLock()

    init(
        chainId: ChainModel.Id,
        params: ERC20BalanceSubscriptionRequest,
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

    private func handleTransactionIfNeeded(for event: EventLog) {
        params.transactionHistoryUpdater?.processERC20Transfer(event: event)
    }

    private func notifyBalanceUpdateIfNeeded(for log: EventLog) {
        guard let eventCenter else {
            return
        }

        let optAssetContract = params.contracts.first {
            let addressData = try? $0.contract.toEthereumAccountId()
            return addressData == log.address.addressData
        }

        guard
            let assetContract = optAssetContract,
            let accountId = try? params.holder.toEthereumAccountId() else {
            return
        }

        let event = AssetBalanceChanged(
            chainAssetId: assetContract.chainAssetId,
            accountId: accountId,
            changes: nil,
            block: log.blockHash
        )

        eventCenter.notify(with: event)
    }

    private func processLog(_ eventLog: EventLog) {
        logProcessMutex.lock()

        defer {
            logProcessMutex.unlock()
        }

        handleTransactionIfNeeded(for: eventLog)

        guard eventLog.blockHash != processingBlockHash else {
            // we are already updating balance for current block
            return
        }

        processingBlockHash = eventLog.blockHash
        syncService?.stopSyncUp()
        syncService = nil

        do {
            logger?.debug("Processing balance for log: \(eventLog)")

            let block = EvmBalanceUpdateBlock(
                updateDetectedAt: .exact(eventLog.blockNumber),
                fetchRequestedAt: .latest
            )

            syncService = try serviceFactory.createERC20BalanceUpdateService(
                for: params.holder,
                chainId: chainId,
                assetContracts: params.contracts,
                block: block
            ) { [weak self] in
                self?.logProcessMutex.lock()

                defer {
                    self?.logProcessMutex.unlock()
                }

                guard self?.processingBlockHash == eventLog.blockHash else {
                    return
                }

                self?.processingBlockHash = nil
                self?.syncService = nil

                self?.notifyBalanceUpdateIfNeeded(for: eventLog)
            }

            syncService?.setup()

            logger?.debug("Start updating balance")
        } catch {
            processingBlockHash = nil
            logger?.error("Can't create sync service: \(error)")
        }
    }

    private func performSubscription() {
        do {
            let contracts = params.contracts.map(\.contract)
            let messageParams = try subscriptionMessageFactory.erc20(for: params.holder, contracts: Set(contracts))

            let updateClosure: (JSONRPCSubscriptionUpdate<EventLog>) -> Void = { [weak self] update in
                let log = update.params.result
                self?.logger?.debug("Did receive evm log: \(log)")

                self?.processLog(log)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            incomingSubscriptionId = try connection.subscribe(
                EvmSubscriptionMessage.subscribeMethod,
                params: messageParams.incomingFilter,
                unsubscribeMethod: EvmSubscriptionMessage.unsubscribeMethod,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            outgoingSubscriptionId = try connection.subscribe(
                EvmSubscriptionMessage.subscribeMethod,
                params: messageParams.outgoingFilter,
                unsubscribeMethod: EvmSubscriptionMessage.unsubscribeMethod,
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            logger?.debug("ERC20 subscription create for \(params.holder)")
        } catch {
            logger?.error("Can't create subscription: \(error)")
        }
    }

    private func unsubscribe() {
        syncService?.stopSyncUp()

        if let incomingSubscriptionId = incomingSubscriptionId {
            connection.cancelForIdentifier(incomingSubscriptionId)
        }

        if let outgoingSubscriptionId = outgoingSubscriptionId {
            connection.cancelForIdentifier(outgoingSubscriptionId)
        }
    }

    private func subscribe() throws {
        guard !params.contracts.isEmpty else {
            logger?.warning("No contracts provided for subscription")
            return
        }

        let block = EvmBalanceUpdateBlock(
            updateDetectedAt: nil,
            fetchRequestedAt: .latest
        )

        syncService = try serviceFactory.createERC20BalanceUpdateService(
            for: params.holder,
            chainId: chainId,
            assetContracts: params.contracts,
            block: block
        ) { [weak self] in
            self?.syncService = nil
            self?.performSubscription()
        }

        syncService?.setup()
    }
}

extension ERC20SubscriptionManager: EvmRemoteSubscriptionProtocol {
    func start() throws {
        try subscribe()
    }

    func stop() throws {
        unsubscribe()
    }
}
