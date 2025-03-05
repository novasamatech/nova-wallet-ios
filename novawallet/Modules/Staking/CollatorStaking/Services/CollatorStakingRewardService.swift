import Foundation
import Operation_iOS

class CollatorStakingRewardService<S> {
    struct PendingRequest {
        let resultClosure: (CollatorStakingRewardCalculatorEngineProtocol) -> Void
        let queue: DispatchQueue?
    }

    let syncQueue: DispatchQueue
    let logger: LoggerProtocol

    private var isActive: Bool = false
    private var snapshot: S?
    private var eventCenter: EventCenterProtocol

    private var pendingRequests: [UUID: PendingRequest] = [:]

    init(
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol,
        syncQueue: DispatchQueue
    ) {
        self.logger = logger
        self.syncQueue = syncQueue
        self.eventCenter = eventCenter
    }

    func start() {
        fatalError("Must be implemented by subsclass")
    }

    func stop() {
        fatalError("Must be implemented by subsclass")
    }

    func deliver(snapshot _: S, to _: PendingRequest) {
        fatalError("Must be implemented by subsclass")
    }

    func updateSnapshotAndNotify(_ snapshot: S, chainId: ChainModel.Id) {
        self.snapshot = snapshot

        notifyPendingClosures(with: snapshot)

        eventCenter.notify(with: StakingRewardInfoChanged(chainId: chainId))
    }
}

private extension CollatorStakingRewardService {
    private func fetchInfoFactory(
        assigning requestId: UUID,
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (CollatorStakingRewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests[requestId] = request
        }
    }

    private func cancel(for requestId: UUID) {
        pendingRequests[requestId] = nil
    }

    private func notifyPendingClosures(with snapshot: S) {
        logger.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = [:]

        requests.values.forEach {
            deliver(snapshot: snapshot, to: $0)
        }

        logger.debug("Fulfilled pendings")
    }
}

extension CollatorStakingRewardService: CollatorStakingRewardCalculatorServiceProtocol {
    func setup() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true

            self.start()
        }
    }

    func throttle() {
        syncQueue.async {
            guard self.isActive else {
                return
            }

            self.isActive = false

            self.stop()
        }
    }

    func fetchCalculatorOperation() -> BaseOperation<CollatorStakingRewardCalculatorEngineProtocol> {
        let requestId = UUID()

        return AsyncClosureOperation(
            operationClosure: { closure in
                self.syncQueue.async {
                    self.fetchInfoFactory(assigning: requestId, runCompletionIn: nil) { info in
                        closure(.success(info))
                    }
                }
            },
            cancelationClosure: {
                self.syncQueue.async {
                    self.cancel(for: requestId)
                }
            }
        )
    }
}
