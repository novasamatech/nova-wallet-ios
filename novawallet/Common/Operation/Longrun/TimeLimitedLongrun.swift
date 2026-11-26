import Foundation
import Operation_iOS

enum TimeLimitedLongrunError: Error, Equatable {
    case timeLimitExceeded
}

final class TimeLimitedLongrun<T>: Longrunable {
    typealias ResultType = T

    let timeLimit: TimeInterval
    let operationQueue: OperationQueue
    let wrapperClosure: () -> CompoundOperationWrapper<T>

    private let mutex = NSLock()
    private var wrapper: CompoundOperationWrapper<T>?
    private var completionClosure: ((Result<T, Error>) -> Void)?

    init(
        timeLimit: TimeInterval,
        operationQueue: OperationQueue,
        wrapperClosure: @escaping () -> CompoundOperationWrapper<T>
    ) {
        self.timeLimit = timeLimit
        self.operationQueue = operationQueue
        self.wrapperClosure = wrapperClosure
    }

    func start(with completionClosure: @escaping (Result<T, Error>) -> Void) {
        let wrapper = wrapperClosure()

        mutex.lock()
        self.wrapper = wrapper
        self.completionClosure = completionClosure
        mutex.unlock()

        let reportingOperation = ClosureOperation<Void> { [weak self] in
            let result = Result { try wrapper.targetOperation.extractNoCancellableResultData() }
            self?.finish(with: result, cancelling: false)
        }

        reportingOperation.addDependency(wrapper.targetOperation)

        DispatchQueue.global().asyncAfter(deadline: .now() + timeLimit) { [weak self] in
            self?.finish(with: .failure(TimeLimitedLongrunError.timeLimitExceeded), cancelling: true)
        }

        operationQueue.addOperations(wrapper.allOperations + [reportingOperation], waitUntilFinished: false)
    }

    func cancel() {
        mutex.lock()
        let pendingWrapper = wrapper
        wrapper = nil
        completionClosure = nil
        mutex.unlock()

        pendingWrapper?.cancel()
    }
}

private extension TimeLimitedLongrun {
    func finish(with result: Result<T, Error>, cancelling: Bool) {
        mutex.lock()
        let closure = completionClosure
        let pendingWrapper = wrapper
        completionClosure = nil
        wrapper = nil
        mutex.unlock()

        guard let closure else {
            return
        }

        if cancelling {
            pendingWrapper?.cancel()
        }

        closure(result)
    }
}
