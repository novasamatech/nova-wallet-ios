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
        let ledgerRequest = MapSubscriptionRequest(
            storagePath: .stakingLedger,
            localKey: Multistaking.NominationPoolStateChange.Key.ledger.rawValue,
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
            requests: [ledgerRequest, bondedPoolRequest],
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()
            
            self?.mutex.unlock()
        }
    }
    
    private func saveState(_ state: Multistaking.NominationPoolStateChange) {
        
    }
}
