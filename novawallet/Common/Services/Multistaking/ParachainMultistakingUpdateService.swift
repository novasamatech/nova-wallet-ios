import Foundation
import SubstrateSdk
import RobinHood

final class ParachainMultistakingUpdateService: BaseSyncService, AnyCancellableCleaning {
    let accountId: AccountId
    let walletId: MetaAccountModel.Id
    let chainAsset: ChainAsset
    let stakingType: StakingType
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let dashboardRepository: AnyDataProviderRepository<Multistaking.DashboardItemParachainPart>
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
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue

        super.init(logger: logger)
    }

    override func performSyncUp() {
        clearSubscription()
        subscribeDelegatorState(for: accountId)
    }

    override func stopSyncUp() {
        clearSubscription()
    }

    private func clearSubscription() {
        subscription = nil
        clearCollatorsFetchRequest()
    }

    private func subscribeDelegatorState(for accountId: AccountId) {
        let request = MapSubscriptionRequest(
            storagePath: ParachainStaking.delegatorStatePath,
            localKey: ""
        ) { BytesCodable(wrappedValue: accountId) }

        subscription = CallbackStorageSubscription<ParachainStaking.Delegator>(
            request: request,
            connection: connection,
            runtimeService: runtimeService,
            repository: nil,
            operationQueue: operationQueue,
            callbackQueue: workingQueue
        ) { [weak self] result in
            self?.mutex.lock()

            self?.handleDelegatorState(result: result)

            self?.mutex.unlock()
        }
    }

    private func handleDelegatorState(result: Result<ParachainStaking.Delegator?, Error>) {
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
            for: { collatorIds },
            connection: connection,
            runtimeService: runtimeService
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

        let stateChange = Multistaking.ParachainStateChange(
            stake: delegator?.staked,
            shouldHaveActiveCollator: shouldHaveActiveCollator
        )

        let stakingOption = Multistaking.OptionWithWallet(
            walletId: walletId,
            option: .init(chainAssetId: chainAsset.chainAssetId, type: stakingType)
        )

        let dashboardItem = Multistaking.DashboardItemParachainPart(
            stakingOption: stakingOption,
            stateChange: stateChange
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
