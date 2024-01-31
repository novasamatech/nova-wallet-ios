import Foundation
import SubstrateSdk

protocol HydraOmnipoolSwapServiceProtocol {
    func createFetchOperation() -> BaseOperation<HydraDx.SwapRemoteState>
}

enum HydraOmnipoolSwapServiceError: Error {
    case unexpectedState
}

final class HydraOmnipoolSwapService: ObservableSyncService {
    let accountId: AccountId
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let workQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var state: HydraDx.SwapRemoteState?
    private var subscription: CallbackBatchStorageSubscription<HydraDx.SwapRemoteStateChange>?

    init(
        accountId: AccountId,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        workQueue: DispatchQueue,
        operationQueue: OperationQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.workQueue = workQueue
        self.operationQueue = operationQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    private func handleStateChangeResult(_ result: Result<HydraDx.SwapRemoteStateChange, Error>) {
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
                    feeCurrency: change.feeCurrency.valueWhenDefined(else: nil),
                    referralLink: change.referralLink.valueWhenDefined(else: nil)
                )
            }

            completeImmediate(nil)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
            completeImmediate(error)
        }
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

            try subscribe(for: accountId)
        } catch {
            completeImmediate(error)
        }
    }

    func subscribe(for accountId: AccountId) throws {
        let feeCurrencyRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.accountFeeCurrency,
                localKey: "",
                keyParamClosure: { BytesCodable(wrappedValue: accountId) }
            ),
            mappingKey: HydraDx.SwapRemoteStateChange.Key.feeCurrency.rawValue
        )

        let referralRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: HydraDx.referralLinkedAccount,
                localKey: "",
                keyParamClosure: { BytesCodable(wrappedValue: accountId) }
            ),
            mappingKey: HydraDx.SwapRemoteStateChange.Key.referralLink.rawValue
        )

        subscription = CallbackBatchStorageSubscription(
            requests: [
                feeCurrencyRequest,
                referralRequest
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
