import Foundation
import SubstrateSdk
import Operation_iOS

typealias MythosStakingDetailsState = UncertainStorage<MythosStakingDetails?>

protocol MythosStakingDetailsSyncServiceProtocol: ApplicationServiceProtocol {
    var currentDetails: MythosStakingDetailsState { get }

    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<MythosStakingDetailsState>.StateChangeClosure
    )

    func remove(observer: AnyObject)
}

final class MythosStakingDetailsSyncService: BaseSyncService {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let syncService: MythosStakingStakeSyncService
    let operationFactory: MythosCollatorOperationFactoryProtocol
    let operationQueue: OperationQueue

    private let syncQueue: DispatchQueue
    private let callStore = CancellableCallStore()

    private var stateObservable: Observable<MythosStakingDetailsState> = .init(state: .undefined)

    var currentDetails: MythosStakingDetailsState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return stateObservable.state
    }

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        syncService: MythosStakingStakeSyncService,
        operationFactory: MythosCollatorOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.syncService = syncService
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue

        syncQueue = DispatchQueue(label: "io.novawallet.mythos.details.sync.\(UUID().uuidString)")
    }

    deinit {
        callStore.cancel()
    }

    override func performSyncUp() {
        clearSubscriptionAndRequest()

        syncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: syncQueue
        ) { [weak self] _, newState in
            guard let self else {
                return
            }

            mutex.lock()

            defer {
                mutex.unlock()
            }

            guard let newState, newState.lastChange.userStake.isDefined else {
                return
            }

            updateDetails(
                userStake: newState.userStake,
                chainId: chainId,
                accountId: accountId,
                blockHash: newState.lastChange.blockHash
            )
        }
    }

    override func stopSyncUp() {
        clearSubscriptionAndRequest()
    }
}

private extension MythosStakingDetailsSyncService {
    func clearSubscriptionAndRequest() {
        syncService.remove(observer: self)

        callStore.cancel()
    }

    func updateDetails(
        userStake: MythosStakingPallet.UserStake?,
        chainId: ChainModel.Id,
        accountId: AccountId,
        blockHash: Data?
    ) {
        callStore.cancel()

        guard let collatorsIds = userStake?.candidates.map(\.wrappedValue) else {
            stateObservable.state = .defined(nil)
            completeImmediate(nil)
            return
        }

        guard !collatorsIds.isEmpty else {
            let details = MythosStakingDetails(
                stakeDistribution: [:],
                maybeLastUnstake: userStake?.maybeLastUnstake
            )

            stateObservable.state = .defined(details)
            completeImmediate(nil)
            return
        }

        let wrapper = operationFactory.createFetchDelegatorStakeDistribution(
            for: chainId,
            delegatorAccountId: accountId,
            collatorIdsClosure: {
                collatorsIds
            },
            blockHash: blockHash
        )

        logger.debug("Will update details at: \(String(describing: blockHash?.toHexWithPrefix()))")

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: syncQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(stakeDistribution):
                let details = MythosStakingDetails(
                    stakeDistribution: stakeDistribution,
                    maybeLastUnstake: userStake?.maybeLastUnstake
                )

                self?.stateObservable.state = .defined(details)

                self?.completeImmediate(nil)
            case let .failure(error):
                self?.logger.error("Update failed: \(error)")
                self?.completeImmediate(error)
            }
        }
    }
}

extension MythosStakingDetailsSyncService: MythosStakingDetailsSyncServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<MythosStakingDetailsState>.StateChangeClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.addObserver(
            with: observer,
            sendStateOnSubscription: sendStateOnSubscription,
            queue: queue,
            closure: closure
        )
    }

    func remove(observer: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stateObservable.removeObserver(by: observer)
    }
}
