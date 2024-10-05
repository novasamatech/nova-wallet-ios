import Foundation
import Operation_iOS
import SubstrateSdk

typealias SwipeGovServiceChangesClosure = (Set<ReferendumIdLocal>, Set<ReferendumIdLocal>) -> Void

protocol SwipeGovServicePrototocol: AnyObject & ObservableSyncServiceProtocol & OpenGovSummaryOperationFactoryProtocol {
    func update(referendums: Set<ReferendumIdLocal>)

    func subscribeReferendums(
        for target: AnyObject,
        notifyingIn queue: DispatchQueue,
        closure: @escaping SwipeGovServiceChangesClosure
    )

    func unsubscribeReferendums(for target: AnyObject)
}

final class SwipeGovService: ObservableSyncService {
    struct Changes: Equatable {
        let new: Set<ReferendumIdLocal>
        let removed: Set<ReferendumIdLocal>

        var hasNew: Bool { !new.isEmpty }
        var hasDeletions: Bool { !removed.isEmpty }

        var hasChanges: Bool { hasNew || hasDeletions }
    }

    let operationFactory: SwipeGovSummaryOperationFactoryProtocol
    let chainId: ChainModel.Id
    let language: String
    let operationQueue: OperationQueue
    let workQueue: DispatchQueue

    private var eligibleReferendums = Observable<Set<ReferendumIdLocal>>(state: [])

    private var pendingUpdateStore = CancellableCallStore()
    private var pendingChanges: Changes?

    private var summaryStore: SwipeGovSummaryById = [:]

    init(
        operationFactory: SwipeGovSummaryOperationFactoryProtocol,
        chainId: ChainModel.Id,
        language: String,
        operationQueue: OperationQueue,
        workQueue: DispatchQueue,
        retryStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        logger: LoggerProtocol = Logger.shared
    ) {
        self.operationFactory = operationFactory
        self.chainId = chainId
        self.language = language
        self.operationQueue = operationQueue
        self.workQueue = workQueue

        super.init(retryStrategy: retryStrategy, logger: logger)
    }

    private func updateState(newSummaries: SwipeGovSummaryById, changes: Changes) {
        var updatedState = eligibleReferendums.state
        updatedState.subtract(changes.removed)
        updatedState.formUnion(Set(newSummaries.keys))

        changes.removed.forEach { referendumId in
            summaryStore[referendumId] = nil
        }

        if !newSummaries.isEmpty {
            summaryStore = summaryStore.merging(newSummaries) { $1 }
        }

        eligibleReferendums.state = updatedState
    }

    override func performSyncUp() {
        guard let pendingChanges else {
            completeImmediate(nil)
            return
        }

        if pendingChanges.hasNew {
            pendingUpdateStore.cancel()

            let wrapper = operationFactory.createFetchWrapper(
                for: chainId,
                languageCode: language,
                referendumIds: pendingChanges.new
            )

            executeCancellable(
                wrapper: wrapper,
                inOperationQueue: operationQueue,
                backingCallIn: pendingUpdateStore,
                runningCallbackIn: workQueue,
                mutex: mutex
            ) { [weak self] result in
                switch result {
                case let .success(summaries):
                    self?.pendingChanges = nil

                    self?.updateState(newSummaries: summaries, changes: pendingChanges)

                    self?.completeImmediate(nil)
                case let .failure(error):
                    self?.completeImmediate(error)
                }
            }
        } else if pendingChanges.hasDeletions {
            self.pendingChanges = nil

            updateState(newSummaries: [:], changes: pendingChanges)
            completeImmediate(nil)
        }
    }

    override func stopSyncUp() {
        pendingUpdateStore.cancel()
        pendingChanges = nil
    }
}

extension SwipeGovService: SwipeGovServicePrototocol {
    func createSummaryOperation(
        for referendumId: ReferendumIdLocal
    ) -> BaseOperation<ReferendumSummary?> {
        ClosureOperation {
            self.mutex.lock()

            defer {
                self.mutex.unlock()
            }

            guard let summary = self.summaryStore[referendumId] else {
                return nil
            }

            return .init(summary: summary)
        }
    }

    private func prepareSyncUp(for referendums: Set<ReferendumIdLocal>) -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let newItems = referendums.subtracting(eligibleReferendums.state)
        let removedItems = eligibleReferendums.state.subtracting(referendums)

        let newChanges = Changes(new: newItems, removed: removedItems)

        if newChanges.hasChanges {
            if pendingChanges != newChanges {
                pendingUpdateStore.cancel()
                pendingChanges = newChanges

                return true
            } else {
                return false
            }
        } else if pendingChanges != nil {
            pendingUpdateStore.cancel()
            pendingChanges = nil
            completeImmediate(nil)

            return false
        } else {
            return false
        }
    }

    func update(referendums: Set<ReferendumIdLocal>) {
        guard prepareSyncUp(for: referendums) else {
            return
        }

        syncUp(afterDelay: 0, ignoreIfSyncing: false)
    }

    func subscribeReferendums(
        for target: AnyObject,
        notifyingIn queue: DispatchQueue,
        closure: @escaping SwipeGovServiceChangesClosure
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        eligibleReferendums.addObserver(
            with: target,
            sendStateOnSubscription: true,
            queue: queue,
            closure: closure
        )
    }

    func unsubscribeReferendums(for target: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        eligibleReferendums.removeObserver(by: target)
    }
}
