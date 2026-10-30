import Foundation
import Operation_iOS
import SubstrateSdk

enum SubtensorShieldInnerSearchError: Error {
    case windowUnfinished(BlockNumber)
}

enum SubtensorShieldInnerScan {
    case found(SubstrateExtrinsicStatus, carrier: SubtensorShieldCarrierLookup)
    case absent(carrier: SubtensorShieldCarrierLookup)
}

final class SubtensorShieldInnerSearch {
    struct Window {
        let start: BlockNumber
        let deadline: BlockNumber
        let pollBudget: Int
        let pollInterval: TimeInterval
    }

    typealias Completion = (Result<SubtensorShieldInnerScan, Error>) -> Void

    let innerHash: ExtrinsicHash
    let carrierHash: ExtrinsicHash
    let matchingEvents: ExtrinsicEventsMatching?
    let connection: JSONRPCEngine
    let statusService: ExtrinsicStatusServiceProtocol
    let operationQueue: OperationQueue

    private let blockHashOperationFactory = BlockHashOperationFactory()
    private let finalizedHeaderOperationFactory = FinalizedHeaderOperationFactory()
    private let workingQueue = DispatchQueue(label: "io.novawallet.mevshield.search.\(UUID().uuidString)")
    private let callStore = CancellableCallStore()
    private let mutex = NSLock()

    private var window: Window?
    private var pollsLeft = 0
    private var completion: Completion?
    private var finalizedNumber: BlockNumber?
    private var carrier: SubtensorShieldCarrierLookup = .absent

    init(
        innerHash: ExtrinsicHash,
        carrierHash: ExtrinsicHash,
        matchingEvents: ExtrinsicEventsMatching?,
        connection: JSONRPCEngine,
        statusService: ExtrinsicStatusServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.innerHash = innerHash
        self.carrierHash = carrierHash
        self.matchingEvents = matchingEvents
        self.connection = connection
        self.statusService = statusService
        self.operationQueue = operationQueue
    }

    func start(window: Window, completion: @escaping Completion) {
        mutex.lock()

        self.window = window
        pollsLeft = window.pollBudget
        self.completion = completion

        mutex.unlock()

        workingQueue.async {
            self.visit(window.start)
        }
    }

    func cancel() {
        mutex.lock()

        completion = nil

        mutex.unlock()

        workingQueue.async {
            self.callStore.cancel()
        }
    }
}

private extension SubtensorShieldInnerSearch {
    var isActive: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return completion != nil
    }

    func visit(_ blockNumber: BlockNumber) {
        guard isActive else {
            return
        }

        // finalized heights only: a carrier is sealed to one author's key, so a reorg can change the outcome
        if let finalizedNumber, finalizedNumber >= blockNumber {
            resolveHash(of: blockNumber)
        } else {
            refreshFinalized(waitingFor: blockNumber)
        }
    }

    func refreshFinalized(waitingFor blockNumber: BlockNumber) {
        executeCancellable(
            wrapper: finalizedHeaderOperationFactory.createBlockNumberWrapper(from: connection),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            if case let .success(number) = result {
                finalizedNumber = max(finalizedNumber ?? 0, number)
            }

            if let finalizedNumber, finalizedNumber >= blockNumber {
                resolveHash(of: blockNumber)
            } else {
                waitAndRevisit(blockNumber)
            }
        }
    }

    func resolveHash(of blockNumber: BlockNumber) {
        guard isActive else {
            return
        }

        let operation = blockHashOperationFactory.createBlockHashOperation(connection: connection) { blockNumber }

        executeCancellable(
            wrapper: CompoundOperationWrapper(targetOperation: operation),
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            if case let .success(blockHash) = result, !blockHash.isEmpty {
                self?.inspect(blockNumber: blockNumber, blockHash: blockHash)
            } else {
                self?.waitAndRevisit(blockNumber)
            }
        }
    }

    func inspect(blockNumber: BlockNumber, blockHash: BlockHash) {
        guard isActive else {
            return
        }

        let wrapper = statusService.fetchExtrinsicStatusesForHashes(
            [innerHash, carrierHash],
            inBlock: blockHash,
            matchingEvents: matchingEvents
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(statuses):
                handle(statuses: statuses, at: blockNumber)
            case .failure:
                waitAndRevisit(blockNumber)
            }
        }
    }

    func handle(statuses: [ExtrinsicHash: Result<SubstrateExtrinsicStatus, Error>], at blockNumber: BlockNumber) {
        record(carrierLookup: statuses[carrierHash])

        switch statuses[innerHash] {
        case let .success(innerStatus):
            finish(with: .success(.found(innerStatus, carrier: carrier)))
        case .failure:
            // an inner whose status cannot be built may have executed, so its height is never passed as absent
            waitAndRevisit(blockNumber)
        case .none:
            advance(from: blockNumber)
        }
    }

    func record(carrierLookup: Result<SubstrateExtrinsicStatus, Error>?) {
        guard case .absent = carrier, let carrierLookup else {
            return
        }

        carrier = switch carrierLookup {
        case let .success(.success(carrierSuccess)):
            .found(carrierSuccess)
        case .success(.failure), .failure:
            .unknown
        }
    }

    func advance(from blockNumber: BlockNumber) {
        guard let deadline = currentWindow()?.deadline, blockNumber < deadline else {
            finish(with: .success(.absent(carrier: carrier)))
            return
        }

        visit(blockNumber + 1)
    }

    func waitAndRevisit(_ blockNumber: BlockNumber) {
        guard let pollInterval = consumePoll() else {
            finish(with: .failure(SubtensorShieldInnerSearchError.windowUnfinished(blockNumber)))
            return
        }

        workingQueue.asyncAfter(deadline: .now() + pollInterval) { [weak self] in
            self?.visit(blockNumber)
        }
    }

    func currentWindow() -> Window? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return window
    }

    func consumePoll() -> TimeInterval? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        pollsLeft -= 1

        guard let window, pollsLeft > 0 else {
            return nil
        }

        return window.pollInterval
    }

    func finish(with result: Result<SubtensorShieldInnerScan, Error>) {
        mutex.lock()

        let currentCompletion = completion
        completion = nil

        mutex.unlock()

        currentCompletion?(result)
    }
}
