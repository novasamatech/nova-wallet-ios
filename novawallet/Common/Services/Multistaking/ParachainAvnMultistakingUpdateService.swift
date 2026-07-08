import Foundation
import SubstrateSdk
import Operation_iOS

/// EWX-specific dashboard sync service.
///
/// Mirrors `ParachainMultistakingUpdateService` (Moonbeam) but subscribes
/// to `NominatorState` instead of `DelegatorState`. The Moonbeam class
/// hardcodes `delegatorStatePath` at two sites — that storage item is
/// absent from EWX runtime metadata, so the dashboard tile for EWT
/// always read as "not staking" until this fork landed.
final class ParachainAvnMultistakingUpdateService: ObservableSyncService, AnyCancellableCleaning {
    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemParachainPart>
    let cacheRepository: AnyDataProviderRepository<ChainStorageItem>
    let operationFactory: ParaStkCollatorsOperationFactoryProtocol
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    private var subscription: CallbackStorageSubscription<ParachainStaking.Delegator>?
    private var collatorsCall: CancellableCall?

    init(
        walletId: MetaAccountModel.Id,
        accountId: AccountId,
        chainAsset: ChainAsset,
        stakingType: StakingType,
        dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemParachainPart>,
        cacheRepository: AnyDataProviderRepository<ChainStorageItem>,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        operationFactory: ParaStkCollatorsOperationFactoryProtocol,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue,
        logger: LoggerProtocol
    ) {
        self.walletId = walletId
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.stakingType = stakingType
        self.dashboardRepository = dashboardRepository
        self.cacheRepository = cacheRepository
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscription()
        subscribeNominatorState(for: accountId)
    }

    override func stopSyncUp() {
        clearSubscription()
    }

    private func clearSubscription() {
        subscription = nil
        clearCollatorsFetchRequest()
    }

    private func subscribeNominatorState(for accountId: AccountId) {
        do {
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                ParachainAvn.nominatorStatePath,
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )

            let request = MapSubscriptionRequest(
                storagePath: ParachainAvn.nominatorStatePath,
                localKey: localKey
            ) { BytesCodable(wrappedValue: accountId) }

            subscription = CallbackStorageSubscription<ParachainStaking.Delegator>(
                request: request,
                connection: connection,
                runtimeService: runtimeService,
                repository: cacheRepository,
                operationQueue: operationQueue,
                callbackQueue: workingQueue
            ) { [weak self] result in
                self?.mutex.lock()

                self?.handleNominatorState(result: result)

                self?.mutex.unlock()
            }
        } catch {
            logger.error("Subscription error: \(error)")

            completeImmediate(error)
        }
    }

    private func handleNominatorState(result: Result<ParachainStaking.Delegator?, Error>) {
        switch result {
        case let .success(delegator):
            clearCollatorsFetchRequest()

            markSyncingImmediate()

            if let delegator = delegator {
                fetchCollatorsAndSaveState(for: delegator)
            } else {
                saveState(for: delegator, collators: [:])
            }
        case let .failure(error):
            completeImmediate(error)
        }
    }

    private func clearCollatorsFetchRequest() {
        clear(cancellable: &collatorsCall)
    }

    private func fetchCollatorsAndSaveState(for delegator: ParachainStaking.Delegator) {
        let collatorIds = delegator.collators()

        let wrapper = operationFactory.createMetadataWrapper(
            for: { collatorIds }
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let workingQueue = self?.workingQueue, let mutex = self?.mutex else {
                return
            }

            dispatchInConcurrent(queue: workingQueue, locking: mutex) {
                guard self?.collatorsCall === wrapper else {
                    return
                }

                self?.collatorsCall = nil

                do {
                    let collatorList = try wrapper.targetOperation.extractNoCancellableResultData()
                    let collatorDict = zip(collatorIds, collatorList).reduce(
                        into: [AccountId: ParachainStaking.CandidateMetadata]()
                    ) {
                        $0[$1.0] = $1.1
                    }

                    self?.saveState(for: delegator, collators: collatorDict)
                } catch {
                    self?.completeImmediate(error)
                }
            }
        }

        collatorsCall = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func saveState(
        for delegator: ParachainStaking.Delegator?,
        collators: [AccountId: ParachainStaking.CandidateMetadata]
    ) {
        let shouldHaveActiveCollator = delegator?.delegations.contains { bond in
            guard let metadata = collators[bond.owner] else {
                return false
            }

            return metadata.isStakeShouldBeActive(for: bond.amount)
        } ?? false

        let state = Multistaking.ParachainState(
            stake: delegator?.staked,
            shouldHaveActiveCollator: shouldHaveActiveCollator
        )

        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let dashboardItem = Multistaking.DashboardItemParachainPart(
            stakingOption: stakingOption,
            state: state
        )

        let operation = dashboardRepository.saveOperation({
            [dashboardItem]
        }, {
            []
        })

        operation.completionBlock = { [weak self] in
            self?.workingQueue.async {
                do {
                    _ = try operation.extractNoCancellableResultData()

                    self?.complete(nil)
                } catch {
                    self?.complete(error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }
}
