import Foundation
import SubstrateSdk

private struct StateKey: Hashable {
    let chainId: ChainModel.Id
    let accountId: AccountId
}

protocol HydraFlowStateStoreSubscriber: AnyObject {
    func flowStateStoreDidUpdate(_ newStates: [HydraFlowState])
}

class HydraFlowStateStore {
    private static var shared: HydraFlowStateStore?

    private var states: [StateKey: WeakWrapper] = [:]
    private var statesUpdatesSubscriptions: [WeakWrapper] = []
    private let mutex = NSLock()
    private let connection: JSONRPCEngine
    private let runtimeProvider: RuntimeProviderProtocol
    private let userStorageFacade: StorageFacadeProtocol
    private let substrateStorageFacade: StorageFacadeProtocol

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.userStorageFacade = userStorageFacade
        self.substrateStorageFacade = substrateStorageFacade
    }
}

private extension HydraFlowStateStore {
    func setupNewFlowState(
        account: ChainAccountResponse,
        chain: ChainModel,
        stateKey: StateKey,
        queue: OperationQueue
    ) throws -> HydraFlowState {
        let flowState = HydraFlowState(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: queue
        )

        states[stateKey] = WeakWrapper(target: flowState)

        statesUpdatesSubscriptions.forEach { sub in
            let mappedStates = states
                .values
                .compactMap { $0.target as? HydraFlowState }

            (sub.target as? HydraFlowStateStoreSubscriber)?.flowStateStoreDidUpdate(mappedStates)
        }

        return flowState
    }

    func clearEmptySubscribers() {
        statesUpdatesSubscriptions.removeAll { $0.target == nil }
    }
}

extension HydraFlowStateStore {
    func setupFlowState(
        account: ChainAccountResponse,
        chain: ChainModel,
        queue: OperationQueue
    ) throws -> HydraFlowState {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        clearEmptySubscribers()

        let stateKey = StateKey(
            chainId: chain.chainId,
            accountId: account.accountId
        )

        let existingState = states[stateKey]?.target as? HydraFlowState

        return if let existingState {
            existingState
        } else {
            try setupNewFlowState(
                account: account,
                chain: chain,
                stateKey: stateKey,
                queue: queue
            )
        }
    }

    func subscribeForChangesUpdates(_ subscriber: HydraFlowStateStoreSubscriber) {
        mutex.lock()

        clearEmptySubscribers()

        let weak = WeakWrapper(target: subscriber)
        statesUpdatesSubscriptions.append(weak)

        mutex.unlock()
    }

    static func getShared(
        for connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        userStorageFacade: StorageFacadeProtocol,
        substrateStorageFacade: StorageFacadeProtocol
    ) -> HydraFlowStateStore {
        if let shared {
            return shared
        }

        let store = HydraFlowStateStore(
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: userStorageFacade,
            substrateStorageFacade: substrateStorageFacade
        )

        shared = store

        return store
    }
}
