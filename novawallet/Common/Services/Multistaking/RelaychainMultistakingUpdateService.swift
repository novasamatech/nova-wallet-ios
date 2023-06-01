import Foundation
import SubstrateSdk
import RobinHood

final class RelaychainMultistakingUpdateService: ObservableSyncService {
    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemRelaychainPart>
    let accountRepository: AnyDataProviderRepository<Multistaking.ResolvedAccount>
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var stateSubscription: CallbackBatchStorageSubscription<Multistaking.RelaychainStateChange>?

    private var controllerSubscription: CallbackBatchStorageSubscription<Multistaking.RelaychainAccountsChange>?

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemRelaychainPart>,
        accountRepository: AnyDataProviderRepository<Multistaking.ResolvedAccount>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.walletId = walletId
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.dashboardRepository = dashboardRepository
        self.accountRepository = accountRepository
        self.connection = connection
        self.runtimeService = runtimeService
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscriptions()

        subscribeControllerResolution(for: accountId)
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

    private func subscribeControllerResolution(for accountId: AccountId) {
        let controllerRequest = MapSubscriptionRequest(
            storagePath: .controller,
            localKey: Multistaking.RelaychainAccountsChange.Key.controller.rawValue
        ) {
            BytesCodable(wrappedValue: accountId)
        }

        let ledgerRequest = MapSubscriptionRequest(
            storagePath: .stakingLedger,
            localKey: Multistaking.RelaychainAccountsChange.Key.stash.rawValue
        ) {
            BytesCodable(wrappedValue: accountId)
        }

        controllerSubscription = CallbackBatchStorageSubscription(
            requests: [controllerRequest, ledgerRequest],
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handleControllerSubscription(result: result, accountId: accountId)

            self?.mutex.unlock()
        }
    }

    private func handleControllerSubscription(
        result: Result<Multistaking.RelaychainAccountsChange, Error>,
        accountId: AccountId
    ) {
        switch result {
        case let .success(accounts):
            if
                case let .defined(stash) = accounts.stash,
                case let .defined(controller) = accounts.controller {
                markSyncingImmediate()

                saveStashChange(stash ?? accountId)

                subscribeState(
                    for: controller ?? accountId,
                    stash: stash ?? accountId
                )
            }
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func subscribeState(for controller: AccountId, stash: AccountId) {
        clearStateSubscription()

        let ledgerRequest = MapSubscriptionRequest(
            storagePath: .stakingLedger,
            localKey: Multistaking.RelaychainStateChange.Key.ledger.rawValue
        ) {
            BytesCodable(wrappedValue: controller)
        }

        let nominationRequest = MapSubscriptionRequest(
            storagePath: .nominators,
            localKey: Multistaking.RelaychainStateChange.Key.nomination.rawValue
        ) {
            BytesCodable(wrappedValue: stash)
        }

        let eraRequest = UnkeyedSubscriptionRequest(
            storagePath: .activeEra,
            localKey: Multistaking.RelaychainStateChange.Key.era.rawValue
        )

        stateSubscription = CallbackBatchStorageSubscription(
            requests: [ledgerRequest, nominationRequest, eraRequest],
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handleStateSubscription(result: result)

            self?.mutex.unlock()
        }
    }

    private func handleStateSubscription(result: Result<Multistaking.RelaychainStateChange, Error>) {
        switch result {
        case let .success(change):
            saveState(change: change)
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func saveStashChange(_ stashAccountId: AccountId) {
        let stakingOption = Multistaking.Option(
            chainAssetId: chainAsset.chainAssetId,
            type: .relaychain
        )

        let resolvedAccount = Multistaking.ResolvedAccount(
            stakingOption: stakingOption,
            walletAccountId: accountId,
            resolvedAccountId: stashAccountId
        )

        let saveOperation = accountRepository.saveOperation({
            [resolvedAccount]
        }, {
            []
        })

        saveOperation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                } catch {
                    self?.logger?.error("Can't save stash account id")
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }

    private func saveState(change: Multistaking.RelaychainStateChange) {
        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let dashboardItem = Multistaking.DashboardItemRelaychainPart(
            stakingOption: stakingOption,
            stateChange: change
        )

        let saveOperation = dashboardRepository.saveOperation({
            [dashboardItem]
        }, {
            []
        })

        saveOperation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                    self?.complete(nil)
                } catch {
                    self?.complete(error)
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}
