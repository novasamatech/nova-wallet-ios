import Foundation
import SubstrateSdk
import Operation_iOS

final class PoolsMultistakingUpdateService: ObservableSyncService, RuntimeConstantFetching {
    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemNominationPoolPart>
    let accountRepository: AnyDataProviderRepository<Multistaking.ResolvedAccount>
    let cacheRepository: AnyDataProviderRepository<ChainStorageItem>
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var poolMemberSubscription: CallbackStorageSubscription<NominationPools.PoolMember>?

    private var stateSubscription: CallbackBatchStorageSubscription<Multistaking.NominationPoolStateChange>?

    private var state: Multistaking.NominationPoolState?

    private lazy var localStorageKeyFactory = LocalStorageKeyFactory()

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemNominationPoolPart>,
        accountRepository: AnyDataProviderRepository<Multistaking.ResolvedAccount>,
        cacheRepository: AnyDataProviderRepository<ChainStorageItem>,
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
        self.connection = connection
        self.runtimeService = runtimeService
        self.workingQueue = workingQueue
        self.operationQueue = operationQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscriptions()

        subscribePoolResolution(for: accountId)
    }

    override func stopSyncUp() {
        state = nil
        clearSubscriptions()
    }

    private func clearSubscriptions() {
        clearPoolMemberSubscription()
        clearStateSubscription()
    }

    private func clearPoolMemberSubscription() {
        poolMemberSubscription = nil
    }

    private func clearStateSubscription() {
        stateSubscription?.unsubscribe()
        stateSubscription = nil
    }

    private func subscribePoolResolution(for accountId: AccountId) {
        do {
            let localKey = try localStorageKeyFactory.createFromStoragePath(
                NominationPools.poolMembersPath,
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )

            let request = MapSubscriptionRequest(storagePath: NominationPools.poolMembersPath, localKey: localKey) {
                BytesCodable(wrappedValue: accountId)
            }

            poolMemberSubscription = CallbackStorageSubscription(
                request: request,
                connection: connection,
                runtimeService: runtimeService,
                repository: cacheRepository,
                operationQueue: operationQueue,
                callbackQueue: workingQueue
            ) { [weak self] result in
                self?.mutex.lock()

                self?.handlePoolMember(result: result, accountId: accountId)

                self?.mutex.unlock()
            }
        } catch {
            logger.error("Pool resolution failed: \(error)")
            completeImmediate(error)
        }
    }

    private func handlePoolMember(result: Result<NominationPools.PoolMember?, Error>, accountId: AccountId) {
        switch result {
        case let .success(optPoolMember):
            markSyncingImmediate()

            if let poolMember = optPoolMember {
                if let state = state, poolMember.poolId == state.poolId {
                    let newState = state.applying(newPoolMember: poolMember)
                    self.state = newState
                    saveState(newState)
                    return
                }

                state = Multistaking.NominationPoolState(
                    poolMember: poolMember,
                    era: nil,
                    ledger: nil,
                    nomination: nil,
                    bondedPool: nil
                )

                resolvePalletIdAndSubscribeState(for: poolMember, accountId: accountId)
            } else {
                saveAccountChanges(for: nil, walletAccountId: accountId)

                state = nil

                saveState(nil)
            }
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func resolvePalletIdAndSubscribeState(for poolMember: NominationPools.PoolMember, accountId: AccountId) {
        let currentPoolSubscription = poolMemberSubscription

        fetchCompoundConstant(
            for: NominationPools.palletIdPath,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue,
            fallbackValue: nil,
            callbackQueue: workingQueue
        ) { [weak self] (result: Result<BytesCodable, Error>) in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            guard self?.poolMemberSubscription === currentPoolSubscription else {
                self?.logger.warning("Tried to query pallet id but subscription changed")
                return
            }

            switch result {
            case let .success(palletId):
                if
                    let poolAccountId = try? NominationPools.derivedAccount(
                        for: poolMember.poolId,
                        accountType: .bonded,
                        palletId: palletId.wrappedValue
                    ) {
                    self?.logger.debug("Derived pool account id: \(poolAccountId.toHex())")

                    self?.saveAccountChanges(for: poolAccountId, walletAccountId: accountId)
                    self?.subscribeState(for: poolAccountId, poolId: poolMember.poolId)
                } else {
                    self?.logger.error("Can't derive pool account id")
                    self?.completeImmediate(CommonError.dataCorruption)
                }
            case let .failure(error):
                self?.logger.error("Can't get pallet id \(error)")
                self?.completeImmediate(error)
            }
        }
    }

    private func saveAccountChanges(for poolAccountId: AccountId?, walletAccountId: AccountId) {
        let stakingOption = Multistaking.Option(chainAssetId: chainAsset.chainAssetId, type: stakingType)

        let saveOperation = accountRepository.saveOperation({
            if let poolAccountId = poolAccountId {
                let account = Multistaking.ResolvedAccount(
                    stakingOption: stakingOption,
                    walletAccountId: walletAccountId,
                    resolvedAccountId: poolAccountId,
                    rewardsAccountId: walletAccountId
                )

                return [account]
            } else {
                return []
            }
        }, {
            if poolAccountId == nil {
                let identifier = Multistaking.ResolvedAccount.createIdentifier(
                    from: walletAccountId,
                    stakingOption: stakingOption
                )

                return [identifier]
            } else {
                return []
            }
        })

        saveOperation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                } catch {
                    self?.logger.error("Can't save pool account id")
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }

    // swiftlint:disable:next function_body_length
    private func subscribeState(for poolAccountId: AccountId, poolId: NominationPools.PoolId) {
        do {
            clearStateSubscription()

            let eraRequest = BatchStorageSubscriptionRequest(
                innerRequest: UnkeyedSubscriptionRequest(
                    storagePath: Staking.activeEra,
                    localKey: ""
                ),
                mappingKey: Multistaking.NominationPoolStateChange.Key.era.rawValue
            )

            let ledgerLocalKey = try localStorageKeyFactory.createFromStoragePath(
                Staking.stakingLedger,
                accountId: poolAccountId,
                chainId: chainAsset.chain.chainId
            )

            let ledgerRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: Staking.stakingLedger,
                    localKey: ledgerLocalKey,
                    keyParamClosure: {
                        BytesCodable(wrappedValue: poolAccountId)
                    }
                ),
                mappingKey: Multistaking.NominationPoolStateChange.Key.ledger.rawValue
            )

            let nominationLocalKey = try localStorageKeyFactory.createFromStoragePath(
                Staking.nominators,
                accountId: poolAccountId,
                chainId: chainAsset.chain.chainId
            )

            let nominationRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: Staking.nominators,
                    localKey: nominationLocalKey,
                    keyParamClosure: {
                        BytesCodable(wrappedValue: poolAccountId)
                    }
                ),
                mappingKey: Multistaking.NominationPoolStateChange.Key.nomination.rawValue
            )

            let bondedLocalKey = try localStorageKeyFactory.createFromStoragePath(
                NominationPools.bondedPoolPath,
                encodableElement: poolId,
                chainId: chainAsset.chain.chainId
            )

            let bondedPoolRequest = BatchStorageSubscriptionRequest(
                innerRequest: MapSubscriptionRequest(
                    storagePath: NominationPools.bondedPoolPath,
                    localKey: bondedLocalKey,
                    keyParamClosure: {
                        StringScaleMapper(value: poolId)
                    }
                ),
                mappingKey: Multistaking.NominationPoolStateChange.Key.bonded.rawValue
            )

            stateSubscription = CallbackBatchStorageSubscription(
                requests: [ledgerRequest, nominationRequest, eraRequest, bondedPoolRequest],
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
            logger.error("Subscription failed: \(error)")
            completeImmediate(error)
        }
    }

    private func handleStateSubscription(result: Result<Multistaking.NominationPoolStateChange, Error>) {
        switch result {
        case let .success(stateChange):
            guard let state = state else {
                completeImmediate(CommonError.dataCorruption)
                logger.error("Expected state but not found")
                return
            }

            let newState = state.applying(change: stateChange)
            self.state = newState

            logger.debug("Pool new state: \(newState)")

            saveState(newState)
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func saveState(_ state: Multistaking.NominationPoolState?) {
        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let dashboardItem = Multistaking.DashboardItemNominationPoolPart(
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
}
