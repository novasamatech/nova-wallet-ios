import Foundation
import SubstrateSdk
import RobinHood

protocol HydraOmnipoolQuoteServiceProtocol {
    func createFetchOperation() -> BaseOperation<HydraDx.QuoteRemoteState>
}

enum HydraOmnipoolQuoteServiceError: Error {
    case unexpectedState
}

final class HydraOmnipoolQuoteService: ObservableSyncService {
    let chain: ChainModel
    let runtimeProvider: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let assetIn: HydraDx.LocalRemoteAssetId
    let assetOut: HydraDx.LocalRemoteAssetId
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private var state: HydraDx.QuoteRemoteState?
    private var subscription: CallbackBatchStorageSubscription<HydraDx.QuoteRemoteStateChange>?

    init(
        chain: ChainModel,
        assetIn: HydraDx.LocalRemoteAssetId,
        assetOut: HydraDx.LocalRemoteAssetId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.chain = chain
        self.assetIn = assetIn
        self.assetOut = assetOut
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.workQueue = workQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    deinit {
        clearSubscription()
    }

    private func handleStateChangeResult(_ result: Result<HydraDx.QuoteRemoteStateChange, Error>) {
        switch result {
        case let .success(change):
            // switch sync state manually if needed to allow others track when new state applied
            if !isSyncing {
                isSyncing = true
            }

            logger.debug("Change: \(change)")

            if let currentState = state {
                state = currentState.merging(newStateChange: change)
            } else {
                state = .init(
                    assetInState: change.assetInState.valueWhenDefined(else: nil),
                    assetOutState: change.assetOutState.valueWhenDefined(else: nil),
                    assetInBalance: change.assetInBalance.valueWhenDefined(else: nil),
                    assetOutBalance: change.assetOutBalance.valueWhenDefined(else: nil),
                    assetInFee: change.assetInFee.valueWhenDefined(else: nil),
                    assetOutFee: change.assetOutFee.valueWhenDefined(else: nil),
                    blockHash: change.blockHash
                )
            }

            completeImmediate(nil)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
            completeImmediate(error)
        }
    }

    private func getBalanceRequest(
        for accountId: AccountId,
        assetId: HydraDx.LocalRemoteAssetId,
        mappingKeyClosure: (Bool) -> HydraDx.QuoteRemoteStateChange.Key
    ) -> BatchStorageSubscriptionRequest {
        if assetId.localAssetId == chain.utilityChainAssetId() {
            return .init(
                innerRequest: MapSubscriptionRequest(
                    storagePath: StorageCodingPath.account,
                    localKey: "",
                    keyParamClosure: {
                        BytesCodable(wrappedValue: accountId)
                    }
                ),
                mappingKey: mappingKeyClosure(true).rawValue
            )
        } else {
            return .init(
                innerRequest: DoubleMapSubscriptionRequest(
                    storagePath: StorageCodingPath.ormlTokenAccount,
                    localKey: "",
                    keyParamClosure: {
                        (BytesCodable(wrappedValue: accountId), StringScaleMapper(value: assetId.remoteAssetId))
                    },
                    param1Encoder: nil,
                    param2Encoder: nil
                ),
                mappingKey: mappingKeyClosure(false).rawValue
            )
        }
    }

    private func getFeeRequest(
        for assetId: HydraDx.LocalRemoteAssetId,
        mappingKey: HydraDx.QuoteRemoteStateChange.Key
    ) -> BatchStorageSubscriptionRequest {
        .init(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.dynamicFees,
                localKey: "",
                keyParamClosure: {
                    StringScaleMapper(value: assetId.remoteAssetId)
                }
            ),
            mappingKey: mappingKey.rawValue
        )
    }

    private func getAssetStateRequest(
        for assetId: HydraDx.LocalRemoteAssetId,
        mappingKey: HydraDx.QuoteRemoteStateChange.Key
    ) -> BatchStorageSubscriptionRequest {
        .init(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.omnipoolAssets,
                localKey: "",
                keyParamClosure: { StringScaleMapper(value: assetId.remoteAssetId) }
            ),
            mappingKey: mappingKey.rawValue
        )
    }

    private func clearSubscription() {
        subscription?.unsubscribe()
        subscription = nil
    }

    override func stopSyncUp() {
        clearSubscription()
    }

    override func performSyncUp() {
        do {
            clearSubscription()

            try subscribe()
        } catch {
            completeImmediate(error)
        }
    }

    func subscribe() throws {
        let assetInStateRequest = getAssetStateRequest(
            for: assetIn,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetInState
        )

        let assetOutStateRequest = getAssetStateRequest(
            for: assetOut,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetOutState
        )

        let poolAccountId = try HydraDx.getPoolAccountId(for: chain.accountIdSize)

        let assetInBalanceRequest = getBalanceRequest(
            for: poolAccountId,
            assetId: assetIn,
            mappingKeyClosure: {
                $0 ? HydraDx.QuoteRemoteStateChange.Key.assetInNativeBalance :
                    HydraDx.QuoteRemoteStateChange.Key.assetInOrmlBalance
            }
        )
        let assetOutBalanceRequest = getBalanceRequest(
            for: poolAccountId,
            assetId: assetOut,
            mappingKeyClosure: {
                $0 ? HydraDx.QuoteRemoteStateChange.Key.assetOutNativeBalance :
                    HydraDx.QuoteRemoteStateChange.Key.assetOutOrmlBalance
            }
        )

        let assetInFeeRequest = getFeeRequest(
            for: assetIn,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetInFee
        )

        let assetOutFeeRequest = getFeeRequest(
            for: assetOut,
            mappingKey: HydraDx.QuoteRemoteStateChange.Key.assetInFee
        )

        subscription = CallbackBatchStorageSubscription(
            requests: [
                assetInStateRequest,
                assetOutStateRequest,
                assetInBalanceRequest,
                assetOutBalanceRequest,
                assetInFeeRequest,
                assetOutFeeRequest
            ],
            connection: connection,
            runtimeService: runtimeProvider,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handleStateChangeResult(result)

            self?.mutex.unlock()
        }

        subscription?.subscribe()
    }
}

extension HydraOmnipoolQuoteService: HydraOmnipoolQuoteServiceProtocol {
    private func lockAndFetchState() -> HydraDx.QuoteRemoteState? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return state
    }

    func createFetchOperation() -> BaseOperation<HydraDx.QuoteRemoteState> {
        ClosureOperation {
            if let state = self.lockAndFetchState() {
                return state
            }

            var fetchedState: HydraDx.QuoteRemoteState?

            let semaphore = DispatchSemaphore(value: 0)

            let subscriber = NSObject()
            self.subscribeSyncState(
                subscriber,
                queue: self.workQueue
            ) { _, newIsSyncing in
                if !newIsSyncing, let state = self.lockAndFetchState() {
                    fetchedState = state
                    self.unsubscribeSyncState(subscriber)

                    semaphore.signal()
                }
            }

            semaphore.wait()

            guard let state = fetchedState else {
                throw HydraOmnipoolQuoteServiceError.unexpectedState
            }

            return state
        }
    }
}
