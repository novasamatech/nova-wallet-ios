import Foundation
import SubstrateSdk
import Operation_iOS

final class PooledBalanceUpdatingService: BaseSyncService, RuntimeConstantFetching {
    let accountId: AccountId
    let chainAsset: ChainAsset
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let repository: AnyDataProviderRepository<PooledAssetBalance>
    let workingQueue: DispatchQueue
    let operationQueue: OperationQueue

    private var poolMemberSubscription: CallbackStorageSubscription<NominationPools.PoolMember>?

    private var stateSubscription: CallbackBatchStorageSubscription<PooledBalanceStateChange>?

    private var state: PooledBalanceState?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        repository: AnyDataProviderRepository<PooledAssetBalance>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.repository = repository
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

        logger.debug("Stop pool external sync for: \(chainAsset.chain.name) \(accountId.toHexString())")
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
        let request = MapSubscriptionRequest(storagePath: NominationPools.poolMembersPath, localKey: .empty) {
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

                state = .init(
                    poolMember: poolMember,
                    ledger: nil,
                    bondedPool: nil,
                    subPools: nil
                )

                resolvePalletIdAndSubscribeState(for: poolMember, accountId: accountId)
            } else {
                state = nil

                saveState(nil)
            }
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func resolvePalletIdAndSubscribeState(for poolMember: NominationPools.PoolMember, accountId _: AccountId) {
        let currentPoolSubscription = poolMemberSubscription

        fetchCompoundConstant(
            for: NominationPools.palletIdPath,
            runtimeCodingService: runtimeService,
            operationManager: OperationManager(operationQueue: operationQueue),
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

    private func subscribeState(for poolAccountId: AccountId, poolId: NominationPools.PoolId) {
        clearStateSubscription()

        let ledgerRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: Staking.stakingLedger,
                localKey: .empty,
                keyParamClosure: {
                    BytesCodable(wrappedValue: poolAccountId)
                }
            ),
            mappingKey: PooledBalanceStateChange.Key.ledger.rawValue
        )

        let subPoolsRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: NominationPools.subPoolsPath,
                localKey: .empty,
                keyParamClosure: {
                    StringScaleMapper(value: poolId)
                }
            ),
            mappingKey: PooledBalanceStateChange.Key.subpools.rawValue
        )

        let bondedPoolRequest = BatchStorageSubscriptionRequest(
            innerRequest: MapSubscriptionRequest(
                storagePath: NominationPools.bondedPoolPath,
                localKey: .empty,
                keyParamClosure: {
                    StringScaleMapper(value: poolId)
                }
            ),
            mappingKey: PooledBalanceStateChange.Key.bonded.rawValue
        )

        stateSubscription = CallbackBatchStorageSubscription(
            requests: [ledgerRequest, bondedPoolRequest, subPoolsRequest],
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

    private func handleStateSubscription(result: Result<PooledBalanceStateChange, Error>) {
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

    private func saveState(_ state: PooledBalanceState?) {
        let optItem: PooledAssetBalance?
        let removeIdentifier: String?

        if let poolId = state?.poolId, let totalStake = state?.totalStake {
            optItem = PooledAssetBalance(
                chainAssetId: chainAsset.chainAssetId,
                accountId: accountId,
                amount: totalStake,
                poolId: poolId
            )

            removeIdentifier = nil
        } else {
            optItem = nil

            removeIdentifier = PooledAssetBalance.createIdentifier(from: chainAsset.chainAssetId, accountId: accountId)
        }

        let saveOperation = repository.saveOperation({
            optItem.map { [$0] } ?? []
        }, {
            removeIdentifier.map { [$0] } ?? []
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
