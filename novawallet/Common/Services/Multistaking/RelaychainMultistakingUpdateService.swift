import Foundation
import SubstrateSdk

final class RelaychainMultistakingUpdateService: BaseSyncService {
    let accountId: AccountId
    let chainAsset: ChainAsset
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let offchainService: OffchainMultistakingUpdateServiceProtocol
    let operationQueue: OperationQueue

    private var stateSubscription: CallbackBatchStorageSubscription<Multistaking.OnchainStateChange>?

    private var controllerSubscription: CallbackStorageSubscription<BytesCodable>?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        offchainService: OffchainMultistakingUpdateServiceProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.offchainService = offchainService
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscriptions()

        subscribeController(for: accountId)
    }

    override func stopSyncUp() {
        clearSubscriptions()
    }

    private func clearSubscriptions() {
        clearControllerSubscription()
        clearStateSubscription()
    }

    private func clearControllerSubscription() {
        controllerSubscription = nil
    }

    private func clearStateSubscription() {
        stateSubscription = nil
    }

    private func subscribeController(for accountId: AccountId) {
        let controllerRequest = MapSubscriptionRequest(
            storagePath: .controller,
            localKey: ""
        ) {
            BytesCodable(wrappedValue: accountId)
        }

        controllerSubscription = CallbackStorageSubscription(
            request: controllerRequest,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: .global(qos: .default)
        ) { [weak self] result in
            self?.handleControllerSubscription(result: result, accountId: accountId)
        }
    }

    private func handleControllerSubscription(
        result: Result<BytesCodable?, Error>,
        accountId: AccountId
    ) {
        switch result {
        case let .success(optData):
            if let controller = optData?.wrappedValue {
                subscribeState(for: controller)

                notifyStashChange(accountId)
            } else {
                subscribeState(for: accountId)
            }

        case let .failure(error):
            complete(error)
        }
    }

    private func subscribeState(for controller: AccountId) {
        let ledgerRequest = MapSubscriptionRequest(
            storagePath: .stakingLedger,
            localKey: Multistaking.OnchainStateChange.Key.ledger.rawValue
        ) {
            BytesCodable(wrappedValue: controller)
        }

        let eraRequest = UnkeyedSubscriptionRequest(
            storagePath: .activeEra,
            localKey: Multistaking.OnchainStateChange.Key.era.rawValue
        )

        stateSubscription = CallbackBatchStorageSubscription(
            requests: [ledgerRequest, eraRequest],
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: .global(qos: .default)
        ) { [weak self] result in
            self?.handleLedgerSubscription(
                result: result,
                controller: controller
            )
        }
    }

    private func handleLedgerSubscription(
        result: Result<Multistaking.OnchainStateChange, Error>,
        controller _: AccountId
    ) {
        switch result {
        case let .success(change):
            saveState(change: change)

            if let stash = change.ledger.value??.stash {
                notifyStashChange(stash)
            }
        case let .failure(error):
            complete(error)
        }
    }

    private func notifyStashChange(_ newStash: AccountId) {
        offchainService.resolveAccountId(newStash, chainAssetId: chainAsset.chainAssetId)
    }

    private func saveState(change _: Multistaking.OnchainStateChange) {
        complete(nil)
    }
}
