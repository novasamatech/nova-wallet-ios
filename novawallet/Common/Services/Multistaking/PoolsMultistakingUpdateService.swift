import Foundation
import SubstrateSdk
import RobinHood

final class PoolsMultistakingUpdateService: ObservableSyncService, RuntimeConstantFetching {
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

    private var poolMemberSubscription: CallbackStorageSubscription<NominationPools.PoolMember>?
    
    private var stateSubscription: CallbackBatchStorageSubscription<Multistaking.NominationPoolStateChange>?
    
    private var state: Multistaking.NominationPoolState?

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
        let request = MapSubscriptionRequest(
            storagePath: NominationPools.poolMembersPath,
            localKey: ""
        ) {
            BytesCodable(wrappedValue: accountId)
        }

        poolMemberSubscription = CallbackStorageSubscription(
            request: request,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handlePoolMember(result: result, accountId: accountId)

            self?.mutex.unlock()
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
                
                let currentPoolSubscription = poolMemberSubscription
                
                fetchCompoundConstant(
                    for: NominationPools.palletId,
                    runtimeCodingService: runtimeService,
                    operationManager: OperationManager(operationQueue: operationQueue)
                ) { [weak self] (result: Result<BytesCodable, Error>) in
                    self?.mutex.lock()
                    
                    defer {
                        self?.mutex.unlock()
                    }
                    
                    guard self?.poolMemberSubscription === currentPoolSubscription else {
                        self?.logger?.warning("Tried to query pallet id but subscription changed")
                        return
                    }

                    do {
                        switch result {
                        case let .success(palletId):
                            let poolAccountId = try NominationPools.derivedAccount(
                                for: poolMember.poolId,
                                accountType: .bonded,
                                palletId: palletId
                            )
                            
                            self?.saveAccountChanges(for: poolAccountId, walletAccountId: accountId)
                            self?.subscribeState(for: poolAccountId, poolId: poolMember.poolId)
                        case let .failure(error):
                            self?.logger?.error("Can't extract pallet id for nomination pools")
                            self?.completeImmediate(error)
                        }
                    } catch {
                        self?.logger?.error("Can't derive pool account id")
                        self?.completeImmediate(error)
                    }

                    
                }
            } else {
                saveAccountChanges(for: nil, walletAccountId: accountId)
                completeImmediate(nil)
            }
        case let .failure(error):
            completeImmediate(error)
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

        saveOperation.completionBlock = {
            self?.workingQueue.async {
                do {
                    _ = try saveOperation.extractNoCancellableResultData()
                } catch {
                    self?.logger?.error("Can't save pool account id")
                }
            }
        }

        operationQueue.addOperation(saveOperation)
    }
    
    private func subscribeState(for poolAccountId: AccountId, poolId: NominationPools.PoolId) {
        let eraRequest = UnkeyedSubscriptionRequest(
            storagePath: .activeEra,
            localKey: Multistaking.NominationPoolStateChange.Key.era.rawValue
        )
        
        let ledgerRequest = MapSubscriptionRequest(
            storagePath: .stakingLedger,
            localKey: Multistaking.NominationPoolStateChange.Key.ledger.rawValue,
            keyParamClosure: {
                BytesCodable(wrappedValue: poolAccountId)
            }
        )
        
        let nominationRequest = MapSubscriptionRequest(
            storagePath: .nominators,
            localKey: Multistaking.NominationPoolStateChange.Key.nomination,
            keyParamClosure: {
                BytesCodable(wrappedValue: poolAccountId)
            }
        )
        
        let bondedPoolRequest = MapSubscriptionRequest(
            storagePath: NominationPools.bondedPool,
            localKey: Multistaking.NominationPoolStateChange.Key.bonded.rawValue,
            keyParamClosure: {
                StringScaleMapper(value: poolId)
            }
        )
        
        stateSubscription = CallbackBatchStorageSubscription(
            requests: [ledgerRequest, nominationRequest, eraRequest, bondedPoolRequest],
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
        
        stateSubscription?.subscribe()
    }
    
    private func handleStateSubscription(result: Result<Multistaking.NominationPoolStateChange, Error>) {
        switch result {
        case let .success(stateChange):
            guard let state = state else {
                completeImmediate(CommonError.dataCorruption)
                logger?.error("Expected state but not found")
                return
            }
            
            let newState = state.applying(change: stateChange)
            
            saveState(newState)
        case let .failure(error):
            completeImmediate(error)
        }
    }
    
    private func saveState(_ state: Multistaking.NominationPoolStateChange) {
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
