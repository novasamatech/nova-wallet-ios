import Foundation
import SubstrateSdk
import Operation_iOS

/**
 * For the parachains, there is an issue that leads to the returning old value if a client subscribes for
 *  it right after changes. This class assures that the new state is applied onchain and notifies the main service
 *  to switch the state.
 */

final class ChainRemoteAccountConfirmService: BaseSyncService {
    let shouldConfirm: Bool

    let accountId: AccountId
    let connection: JSONRPCEngine
    let callbackQueue: DispatchQueue
    let detectionClosure: () -> Void

    let storageKeyFactory = StorageKeyFactory()

    private var subscription: StorageSubscriptionContainer?
    private var isConfirming: Bool = false

    init(
        accountId: AccountId,
        connection: JSONRPCEngine,
        shouldConfirm: Bool,
        detectionClosure: @escaping () -> Void,
        callbackQueue: DispatchQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(multiplier: 1),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.accountId = accountId
        self.connection = connection
        self.detectionClosure = detectionClosure
        self.callbackQueue = callbackQueue
        self.shouldConfirm = shouldConfirm

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    private func retryConfirmation() {
        retryAttempt += 1

        subscription = nil

        retry()
    }

    private func handleHasAccount(_ hasAccount: Bool) {
        guard hasAccount else {
            if isConfirming {
                retryConfirmation()
            }

            return
        }

        if isConfirming || !shouldConfirm {
            subscription = nil
            dispatchInQueueWhenPossible(callbackQueue, block: detectionClosure)
        } else {
            isConfirming = true
            retryAttempt = 0
            retryConfirmation()
        }
    }

    override func performSyncUp() {
        do {
            let remoteKey = try storageKeyFactory.accountInfoKeyForId(accountId)

            let handler = RawDataStorageSubscription(remoteStorageKey: remoteKey) { [weak self] data, _ in
                let hasAccount = data != nil

                self?.mutex.lock()

                defer {
                    self?.mutex.unlock()
                }

                self?.handleHasAccount(hasAccount)
            }

            subscription = StorageSubscriptionContainer(
                engine: connection,
                children: [handler],
                logger: logger
            )
        } catch {
            completeImmediate(error)
        }
    }

    override func stopSyncUp() {
        subscription = nil
    }
}
