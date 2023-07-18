import Foundation
import SubstrateSdk
import RobinHood

final class PoolsMultistakingUpdateService: ObservableSyncService {
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
        poolMemberSubscription = nil
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
            if let poolMember = optPoolMember {
                
            } else {
                
            }
        case let .failure(error):
            completeImmediate(error)
        }
    }
    
    private func save
}
