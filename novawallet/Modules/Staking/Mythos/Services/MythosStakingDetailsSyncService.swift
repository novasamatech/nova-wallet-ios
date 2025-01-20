import Foundation
import SubstrateSdk
import Operation_iOS

protocol MythosStakingDetailsSyncServiceProtocol: ApplicationServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<MythosStakingDetails?>.StateChangeClosure
    )

    func remove(observer: AnyObject)
}

final class MythosStakingDetailsSyncService: BaseSyncService {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let chainRegistry: ChainRegistryProtocol
    let operationFactory: MythosCollatorOperationFactoryProtocol
    let operationQueue: OperationQueue

    private let syncQueue: DispatchQueue
    private let localKeyFactory = LocalStorageKeyFactory()
    private let callStore = CancellableCallStore()

    private var subscription: CallbackStorageSubscription<MythosStakingPallet.UserStake>?

    private var stateObservable: Observable<MythosStakingDetails?> = .init(state: nil)

    init(
        chainId: ChainModel.Id,
        accountId: AccountId,
        chainRegistry: ChainRegistryProtocol,
        operationFactory: MythosCollatorOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainId = chainId
        self.accountId = accountId
        self.chainRegistry = chainRegistry
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue

        syncQueue = DispatchQueue(label: "io.novawallet.mythos.details.sync.\(UUID().uuidString)")
    }

    deinit {
        clearSubscriptionAndRequest()
    }

    private func updateDetails(
        userStake: MythosStakingPallet.UserStake?,
        chainId: ChainModel.Id,
        accountId: AccountId,
        blockHash: Data?
    ) {
        callStore.cancel()

        guard let collatorsIds = userStake?.candidates.map(\.wrappedValue) else {
            stateObservable.state = nil
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

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: syncQueue,
            mutex: mutex
        ) { [weak self] result in
            switch result {
            case let .success(stakeDistribution):
                self?.stateObservable.state = MythosStakingDetails(stakeDistribution: stakeDistribution)
                self?.completeImmediate(nil)
            case let .failure(error):
                self?.complete(error)
            }
        }
    }

    private func createUserStakeRequest(
        for chainId: ChainModel.Id,
        accountId: AccountId
    ) throws -> MapSubscriptionRequest<BytesCodable> {
        let localKey = try localKeyFactory.createFromStoragePath(
            MythosStakingPallet.userStakePath,
            accountId: accountId,
            chainId: chainId
        )

        return MapSubscriptionRequest(
            storagePath: MythosStakingPallet.userStakePath,
            localKey: localKey,
            keyParamClosure: {
                BytesCodable(wrappedValue: accountId)
            }
        )
    }

    private func clearSubscriptionAndRequest() {
        subscription?.unsubscribe()
        subscription = nil

        callStore.cancel()
    }

    private func setupSubscription(for chainId: ChainModel.Id, accountId: AccountId) throws {
        let connection = try chainRegistry.getConnectionOrError(for: chainId)
        let runtimeProvider = try chainRegistry.getRuntimeProviderOrError(for: chainId)

        let request = try createUserStakeRequest(for: chainId, accountId: accountId)

        subscription = CallbackStorageSubscription(
            request: request,
            connection: connection,
            runtimeService: runtimeProvider,
            repository: nil,
            operationQueue: operationQueue,
            callbackWithBlockQueue: syncQueue
        ) { [weak self] result in
            self?.mutex.lock()

            defer {
                self?.mutex.unlock()
            }

            switch result {
            case let .success(response):
                self?.updateDetails(
                    userStake: response.value,
                    chainId: chainId,
                    accountId: accountId,
                    blockHash: response.blockHash
                )
            case let .failure(error):
                self?.completeImmediate(error)
            }
        }
    }

    override func performSyncUp() {
        clearSubscriptionAndRequest()

        do {
            try setupSubscription(for: chainId, accountId: accountId)
        } catch {
            completeImmediate(error)
        }
    }

    override func stopSyncUp() {
        clearSubscriptionAndRequest()
    }
}

extension MythosStakingDetailsSyncService: MythosStakingDetailsSyncServiceProtocol {
    func add(
        observer: AnyObject,
        sendStateOnSubscription: Bool,
        queue: DispatchQueue?,
        closure: @escaping Observable<MythosStakingDetails?>.StateChangeClosure
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
