import Foundation
import Operation_iOS
import SubstrateSdk

final class SubtensorShieldInnerSearch {
    struct Window {
        let deadline: BlockNumber
        let pollBudget: Int
        let pollInterval: TimeInterval
    }

    typealias Completion = (Result<SubstrateExtrinsicStatus?, Error>) -> Void

    let innerHash: ExtrinsicHash
    let matchingEvents: ExtrinsicEventsMatching?
    let connection: JSONRPCEngine
    let statusService: ExtrinsicStatusServiceProtocol
    let operationQueue: OperationQueue

    private let blockHashOperationFactory = BlockHashOperationFactory()
    private let workingQueue = DispatchQueue(label: "io.novawallet.mevshield.search.\(UUID().uuidString)")
    private let callStore = CancellableCallStore()
    private let mutex = NSLock()

    private var window: Window?
    private var pollsLeft = 0
    private var completion: Completion?

    init(
        innerHash: ExtrinsicHash,
        matchingEvents: ExtrinsicEventsMatching?,
        connection: JSONRPCEngine,
        statusService: ExtrinsicStatusServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.innerHash = innerHash
        self.matchingEvents = matchingEvents
        self.connection = connection
        self.statusService = statusService
        self.operationQueue = operationQueue
    }

    func start(
        from blockNumber: BlockNumber,
        blockHash: BlockHash?,
        window: Window,
        completion: @escaping Completion
    ) {
        mutex.lock()

        self.window = window
        pollsLeft = window.pollBudget
        self.completion = completion

        mutex.unlock()

        workingQueue.async {
            if let blockHash {
                self.inspect(blockNumber: blockNumber, blockHash: blockHash)
            } else {
                self.resolveHash(of: blockNumber)
            }
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

    func inspect(blockNumber: BlockNumber, blockHash: BlockHash) {
        guard isActive else {
            return
        }

        let wrapper = statusService.fetchExtrinsicStatusForHash(
            innerHash,
            inBlock: blockHash,
            matchingEvents: matchingEvents
        )

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: workingQueue
        ) { [weak self] result in
            switch result {
            case let .success(status):
                self?.finish(with: .success(status))
            case let .failure(error):
                if case ExtrinsicStatusServiceError.extrinsicNotFound = error {
                    self?.advance(from: blockNumber)
                } else {
                    self?.finish(with: .failure(error))
                }
            }
        }
    }

    func advance(from blockNumber: BlockNumber) {
        guard let deadline = currentWindow()?.deadline, blockNumber < deadline else {
            finish(with: .success(nil))
            return
        }

        resolveHash(of: blockNumber + 1)
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
                self?.waitForBlock(blockNumber)
            }
        }
    }

    func waitForBlock(_ blockNumber: BlockNumber) {
        guard let pollInterval = consumePoll() else {
            finish(with: .success(nil))
            return
        }

        workingQueue.asyncAfter(deadline: .now() + pollInterval) { [weak self] in
            self?.resolveHash(of: blockNumber)
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

    func finish(with result: Result<SubstrateExtrinsicStatus?, Error>) {
        mutex.lock()

        let currentCompletion = completion
        completion = nil

        mutex.unlock()

        currentCompletion?(result)
    }
}
