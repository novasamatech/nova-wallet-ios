import Foundation

protocol BittensorAttestedExecutorJob: AnyObject {
    func run()
}

enum BittensorSignAdmission {
    case granted
    case refused(BittensorApiError)
    case cancelled
}

final class BittensorAttestedRequestExecutor {
    struct PendingAdmission {
        let job: BittensorAttestedExecutorJob
        let deadline: TimeInterval
        let completion: (BittensorSignAdmission) -> Void
    }

    enum Decision {
        case settled(BittensorSignAdmission)
        case wait(TimeInterval)
    }

    private let timeProvider: () -> TimeInterval
    private let mutex = NSLock()

    private var pendingJobs: [BittensorAttestedExecutorJob] = []
    private var activeJob: BittensorAttestedExecutorJob?
    private var pendingAdmission: PendingAdmission?
    private var budget = BittensorSignBudget()
    private var isRejectionLatched = false
    private var scheduler: SchedulerProtocol?

    init(timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now) {
        self.timeProvider = timeProvider
    }

    func now() -> TimeInterval {
        timeProvider()
    }

    func submit(_ job: BittensorAttestedExecutorJob) {
        mutex.lock()

        pendingJobs.append(job)

        let nextJob = activateNextJobIfIdle()

        mutex.unlock()

        run(nextJob)
    }

    func cancel(_ job: BittensorAttestedExecutorJob) {
        mutex.lock()

        if let index = pendingJobs.firstIndex(where: { $0 === job }) {
            pendingJobs.remove(at: index)
            mutex.unlock()

            return
        }

        guard let admission = pendingAdmission, admission.job === job else {
            mutex.unlock()

            return
        }

        pendingAdmission = nil
        scheduler?.cancel()

        mutex.unlock()

        admission.completion(.cancelled)
    }

    func admitSignAttempt(
        for job: BittensorAttestedExecutorJob,
        deadline: TimeInterval,
        completion: @escaping (BittensorSignAdmission) -> Void
    ) {
        mutex.lock()

        guard activeJob === job else {
            mutex.unlock()

            completion(.cancelled)

            return
        }

        switch decideAdmission(deadline: deadline) {
        case let .settled(admission):
            mutex.unlock()

            completion(admission)
        case let .wait(delay):
            pendingAdmission = PendingAdmission(job: job, deadline: deadline, completion: completion)
            schedule(after: delay)

            mutex.unlock()
        }
    }

    func finish(_ job: BittensorAttestedExecutorJob) {
        mutex.lock()

        guard activeJob === job else {
            mutex.unlock()

            return
        }

        activeJob = nil

        let nextJob = activateNextJobIfIdle()

        mutex.unlock()

        run(nextJob)
    }

    func latchRejection() {
        mutex.lock()

        isRejectionLatched = true

        mutex.unlock()
    }

    func startChallengeCooldown() {
        mutex.lock()

        budget.startCooldown(at: timeProvider())

        mutex.unlock()
    }
}

private extension BittensorAttestedRequestExecutor {
    func activateNextJobIfIdle() -> BittensorAttestedExecutorJob? {
        guard activeJob == nil, !pendingJobs.isEmpty else {
            return nil
        }

        let nextJob = pendingJobs.removeFirst()
        activeJob = nextJob

        return nextJob
    }

    func run(_ job: BittensorAttestedExecutorJob?) {
        guard let job else {
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            job.run()
        }
    }

    func decideAdmission(deadline: TimeInterval) -> Decision {
        guard !isRejectionLatched else {
            return .settled(.refused(.attestationRejected(requestId: nil)))
        }

        let time = timeProvider()

        switch budget.admit(at: time) {
        case .granted:
            return .settled(.granted)
        case .coolingDown:
            return .settled(.refused(.rateLimited(requestId: nil)))
        case let .exhausted(nextAvailableAt):
            guard nextAvailableAt <= deadline else {
                return .settled(.refused(.rateLimited(requestId: nil)))
            }

            return .wait(max(nextAvailableAt - time, 0))
        }
    }

    func schedule(after delay: TimeInterval) {
        let activeScheduler = scheduler ?? Scheduler(with: self, callbackQueue: .global(qos: .userInitiated))
        scheduler = activeScheduler

        activeScheduler.notifyAfter(delay)
    }
}

extension BittensorAttestedRequestExecutor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        mutex.lock()

        guard let admission = pendingAdmission else {
            mutex.unlock()

            return
        }

        switch decideAdmission(deadline: admission.deadline) {
        case let .settled(result):
            pendingAdmission = nil

            mutex.unlock()

            admission.completion(result)
        case let .wait(delay):
            schedule(after: delay)

            mutex.unlock()
        }
    }
}
