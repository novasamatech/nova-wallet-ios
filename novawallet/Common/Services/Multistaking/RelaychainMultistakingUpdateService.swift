import Foundation
import SubstrateSdk
import Operation_iOS

final class RelaychainMultistakingUpdateService: ObservableSyncService {
    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemRelaychainPart>
    let accountRepository: AnyDataProviderRepository<Multistaking.ResolvedAccount>
    let cacheRepository: AnyDataProviderRepository<ChainStorageItem>
    let stashItemRepository: AnyDataProviderRepository<StashItem>
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var stateSubscription: CallbackBatchStorageSubscription<Multistaking.RelaychainStateChange>?

    private var controllerSubscription: CallbackBatchStorageSubscription<Multistaking.RelaychainAccountsChange>?

    private var state: Multistaking.RelaychainState?

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemRelaychainPart>,
        accountRepository: AnyDataProviderRepository<Multistaking.ResolvedAccount>,
        cacheRepository: AnyDataProviderRepository<ChainStorageItem>,
        stashItemRepository: AnyDataProviderRepository<StashItem>,
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
        self.cacheRepository = cacheRepository
        self.stashItemRepository = stashItemRepository
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
        controllerSubscription?.unsubscribe()
        controllerSubscription = nil
    }

    private func clearStateSubscription() {
        stateSubscription?.unsubscribe()
        stateSubscription = nil
    }

    private func subscribeControllerResolution(for accountId: AccountId) {
        let controllerRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: Staking.controller,
                localKey: ""
            ) {
                BytesCodable(wrappedValue: accountId)
            },
            mappingKey: Multistaking.RelaychainAccountsChange.Key.controller.rawValue
        )

        let ledgerRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: Staking.stakingLedger,
                localKey: ""
            ) {
                BytesCodable(wrappedValue: accountId)
            },
            mappingKey: Multistaking.RelaychainAccountsChange.Key.stash.rawValue
        )

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

        controllerSubscription?.subscribe()
    }

    private func handleControllerSubscription(
        result: Result<Multistaking.RelaychainAccountsChange, Error>,
        accountId: AccountId
    ) {
        switch result {
        case let .success(accounts):
            if
                case let .defined(remoteStash) = accounts.stash,
                case let .defined(remoteController) = accounts.controller {
                markSyncingImmediate()

                let stash: AccountId?
                let controller: AccountId?

                if remoteStash != nil || remoteController != nil {
                    if remoteStash != nil, remoteController != nil {
                        // stash and controller at the same time - prefer stash
                        stash = accountId
                        controller = remoteController ?? accountId
                    } else {
                        stash = remoteStash ?? accountId
                        controller = remoteController ?? accountId
                    }
                } else {
                    stash = nil
                    controller = nil
                }

                saveResolvedAccounts(stash ?? accountId)

                saveStashItem(stash: stash, controller: controller, chain: chainAsset.chain)

                subscribeState(for: controller ?? accountId, stash: stash ?? accountId)
            }
        case let .failure(error):
            completeImmediate(error)
        }
    }

    // swiftlint:disable:next function_body_length
    private func subscribeState(for controller: AccountId, stash: AccountId) {
        do {
            clearStateSubscription()

            let localKeyFactory = LocalStorageKeyFactory()

            let ledgerLocalKey = try localKeyFactory.createFromStoragePath(
                Staking.stakingLedger,
                accountId: controller,
                chainId: chainAsset.chain.chainId
            )

            let ledgerRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: Staking.stakingLedger,
                    localKey: ledgerLocalKey
                ) {
                    BytesCodable(wrappedValue: controller)
                },
                mappingKey: Multistaking.RelaychainStateChange.Key.ledger.rawValue
            )

            let nominationLocalKey = try localKeyFactory.createFromStoragePath(
                Staking.nominators,
                accountId: stash,
                chainId: chainAsset.chain.chainId
            )

            let nominationRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: Staking.nominators,
                    localKey: nominationLocalKey
                ) {
                    BytesCodable(wrappedValue: stash)
                },
                mappingKey: Multistaking.RelaychainStateChange.Key.nomination.rawValue
            )

            let validatorLocalKey = try localKeyFactory.createFromStoragePath(
                Staking.validatorPrefs,
                accountId: stash,
                chainId: chainAsset.chain.chainId
            )

            let validatorRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: Staking.validatorPrefs,
                    localKey: validatorLocalKey
                ) {
                    BytesCodable(wrappedValue: stash)
                },
                mappingKey: Multistaking.RelaychainStateChange.Key.validatorPrefs.rawValue
            )

            let eraRequest = BatchStorageSubscriptionRequest(
                innerRequest: UnkeyedSubscriptionRequest(
                    storagePath: Staking.activeEra,
                    localKey: ""
                ),
                mappingKey: Multistaking.RelaychainStateChange.Key.era.rawValue
            )

            stateSubscription = CallbackBatchStorageSubscription(
                requests: [ledgerRequest, nominationRequest, validatorRequest, eraRequest],
                connection: connection,
                runtimeService: runtimeService,
                repository: cacheRepository,
                operationQueue: operationQueue,
                callbackQueue: workingQueue
            ) { [weak self] result in
                self?.mutex.lock()

                self?.handleStateSubscription(result: result)

                self?.mutex.unlock()
            }

            stateSubscription?.subscribe()
        } catch {
            logger.error("Local key failed: \(error)")
            completeImmediate(error)
        }
    }

    private func handleStateSubscription(result: Result<Multistaking.RelaychainStateChange, Error>) {
        switch result {
        case let .success(change):
            if let newState = updateState(from: change) {
                saveState(newState)
            }
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func updateState(from change: Multistaking.RelaychainStateChange) -> Multistaking.RelaychainState? {
        if let currentState = state {
            let newState = currentState.applying(change: change)
            state = newState
            return newState
        } else if
            case let .defined(era) = change.era,
            case let .defined(ledger) = change.ledger,
            case let .defined(nomination) = change.nomination,
            case let .defined(validatorPrefs) = change.validatorPrefs {
            let state = Multistaking.RelaychainState(
                era: era,
                ledger: ledger,
                nomination: nomination,
                validatorPrefs: validatorPrefs
            )

            self.state = state

            return state
        } else {
            return nil
        }
    }

    private func saveResolvedAccounts(_ stashAccountId: AccountId) {
        let stakingOption = Multistaking.Option(
            chainAssetId: chainAsset.chainAssetId,
            type: stakingType
        )

        let resolvedAccount = Multistaking.ResolvedAccount(
            stakingOption: stakingOption,
            walletAccountId: accountId,
            resolvedAccountId: stashAccountId,
            rewardsAccountId: stashAccountId
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
                    self?.logger.error("Can't save stash account id")
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }

    private func saveState(_ state: Multistaking.RelaychainState) {
        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let dashboardItem = Multistaking.DashboardItemRelaychainPart(
            stakingOption: stakingOption,
            state: state
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

    private func saveStashItem(stash: AccountId?, controller: AccountId?, chain: ChainModel) {
        logger.debug(
            "Saving stash item \(chain.name): \(String(describing: stash)) \(String(describing: controller))"
        )

        let saveOperation = stashItemRepository.replaceOperation {
            if let stash = stash, let controller = controller {
                let stashItem = StashItem(
                    stash: try stash.toAddress(using: chain.chainFormat),
                    controller: try controller.toAddress(using: chain.chainFormat),
                    chainId: chain.chainId
                )

                return [stashItem]
            } else {
                return []
            }
        }

        saveOperation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                } catch {
                    self?.logger.error("Can't save stash item")
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
}
