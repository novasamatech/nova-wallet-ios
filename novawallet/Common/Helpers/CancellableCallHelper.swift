import Foundation
import Operation_iOS

// Every access to the stored call goes through `mutex`: `store`/`clear`/`cancel`/`clearIfMatches`
// are routinely called from a callback queue and from a teardown path on another thread at the
// same time, and an unsynchronised swap lets two threads read the same reference and release it
// twice. `cancel()` runs outside the lock because cancelling an operation graph can invoke a
// completion block synchronously, which re-enters `clearIfMatches` (NSLock is not recursive).
final class CancellableCallStore {
    private let mutex = NSLock()
    private var call: OperatingCall?

    var operatingCall: OperatingCall? {
        mutex.lock()
        defer { mutex.unlock() }

        return call
    }

    var hasCall: Bool {
        operatingCall != nil
    }

    // Returns the displaced call so it is always released by the caller, outside the lock.
    private func exchange(_ newCall: OperatingCall?, ifMatching expected: CancellableCall? = nil) -> OperatingCall? {
        mutex.lock()
        defer { mutex.unlock() }

        if let expected, call !== expected {
            return nil
        }

        let previous = call
        call = newCall

        return previous
    }

    func store(call newCall: OperatingCall) {
        _ = exchange(newCall)
    }

    func clear() {
        _ = exchange(nil)
    }

    func cancel() {
        exchange(nil)?.cancel()
    }

    func clearIfMatches(call expected: OperatingCall) -> Bool {
        exchange(nil, ifMatching: expected) != nil
    }

    func matches(call expected: CancellableCall) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }

        return call === expected
    }

    func addDependency(to newCall: OperatingCall) {
        guard let pendingCall = operatingCall else {
            return
        }

        newCall.allOperations.forEach { op1 in
            pendingCall.allOperations.forEach { op2 in
                op1.addDependency(op2)
            }
        }
    }
}

func execute<T>(
    wrapper: CompoundOperationWrapper<T>,
    inOperationQueue operationQueue: OperationQueue,
    runningCallbackIn callbackQueue: DispatchQueue?,
    callbackClosure: @escaping (Result<T, Error>) -> Void
) {
    wrapper.targetOperation.completionBlock = {
        dispatchInQueueWhenPossible(callbackQueue) {
            do {
                let value = try wrapper.targetOperation.extractNoCancellableResultData()
                callbackClosure(.success(value))
            } catch {
                callbackClosure(.failure(error))
            }
        }
    }

    operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
}

func executeCancellable<T>(
    wrapper: CompoundOperationWrapper<T>,
    inOperationQueue operationQueue: OperationQueue,
    backingCallIn callStore: CancellableCallStore,
    runningCallbackIn callbackQueue: DispatchQueue?,
    mutex: NSLock? = nil,
    callbackClosure: @escaping (Result<T, Error>) -> Void
) {
    wrapper.targetOperation.completionBlock = {
        dispatchInQueueWhenPossible(callbackQueue, locking: mutex) {
            guard callStore.clearIfMatches(call: wrapper) else {
                return
            }

            do {
                let value = try wrapper.targetOperation.extractNoCancellableResultData()
                callbackClosure(.success(value))
            } catch {
                callbackClosure(.failure(error))
            }
        }
    }

    callStore.store(call: wrapper)

    operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
}

func execute<T>(
    operation: BaseOperation<T>,
    inOperationQueue operationQueue: OperationQueue,
    runningCallbackIn callbackQueue: DispatchQueue?,
    callbackClosure: @escaping (Result<T, Error>) -> Void
) {
    operation.completionBlock = {
        dispatchInQueueWhenPossible(callbackQueue) {
            do {
                let value = try operation.extractNoCancellableResultData()
                callbackClosure(.success(value))
            } catch {
                callbackClosure(.failure(error))
            }
        }
    }

    operationQueue.addOperations([operation], waitUntilFinished: false)
}

func execute<T>(
    operation: BaseOperation<T>,
    inOperationQueue operationQueue: OperationQueue,
    backingCallIn callStore: CancellableCallStore,
    runningCallbackIn callbackQueue: DispatchQueue?,
    callbackClosure: @escaping (Result<T, Error>) -> Void
) {
    operation.completionBlock = {
        dispatchInQueueWhenPossible(callbackQueue) {
            guard callStore.clearIfMatches(call: operation) else {
                return
            }

            do {
                let value = try operation.extractNoCancellableResultData()
                callbackClosure(.success(value))
            } catch {
                callbackClosure(.failure(error))
            }
        }
    }

    callStore.store(call: operation)

    operationQueue.addOperations([operation], waitUntilFinished: false)
}
