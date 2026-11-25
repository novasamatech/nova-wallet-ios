import Foundation
import Operation_iOS

/// Runs the primary operation and, if it fails, the fallback one. The result is either
/// the first success or the fallback's failure.
///
/// The operations are started directly instead of being enqueued: the longrun usually backs an operation
/// that already occupies a slot of the caller's queue, so waiting for the same queue would stall a serial one.
/// That is safe only for operations that don't block in `start()`, such as the network ones.
final class OperationFallbackLongrun<T>: Longrunable {
    typealias ResultType = T

    private let primaryClosure: () -> BaseOperation<T>
    private let fallbackClosure: () -> BaseOperation<T>

    private let mutex = NSLock()
    private var isCancelled = false
    private var pendingOperation: BaseOperation<T>?
    private var completionClosure: ((Result<T, Error>) -> Void)?

    init(
        primaryClosure: @escaping () -> BaseOperation<T>,
        fallbackClosure: @escaping () -> BaseOperation<T>
    ) {
        self.primaryClosure = primaryClosure
        self.fallbackClosure = fallbackClosure
    }

    func start(with completionClosure: @escaping (Result<T, Error>) -> Void) {
        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()
            return
        }

        let operation = createOperation(using: primaryClosure, isFallback: false)
        pendingOperation = operation
        self.completionClosure = completionClosure

        mutex.unlock()

        operation.start()
    }

    func cancel() {
        mutex.lock()

        let operation = pendingOperation
        isCancelled = true
        pendingOperation = nil
        completionClosure = nil

        mutex.unlock()

        operation?.cancel()
    }
}

private extension OperationFallbackLongrun {
    func createOperation(using closure: () -> BaseOperation<T>, isFallback: Bool) -> BaseOperation<T> {
        let operation = closure()

        operation.completionBlock = { [weak self] in
            let result = Result { try operation.extractNoCancellableResultData() }
            self?.handle(result: result, of: operation, isFallback: isFallback)
        }

        return operation
    }

    func handle(result: Result<T, Error>, of operation: BaseOperation<T>, isFallback: Bool) {
        mutex.lock()

        // the longrun was cancelled while the operation was in flight
        guard pendingOperation === operation else {
            mutex.unlock()
            return
        }

        if case .failure = result, !isFallback {
            let fallbackOperation = createOperation(using: fallbackClosure, isFallback: true)
            pendingOperation = fallbackOperation

            mutex.unlock()

            fallbackOperation.start()
            return
        }

        let closure = completionClosure
        pendingOperation = nil
        completionClosure = nil

        mutex.unlock()

        closure?(result)
    }
}
