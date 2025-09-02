import Foundation
import Operation_iOS

final class CancellableCallStore {
    private(set) var operatingCall: OperatingCall?

    var hasCall: Bool {
        operatingCall != nil
    }

    func store(call: OperatingCall) {
        operatingCall = call
    }

    func clear() {
        operatingCall = nil
    }

    func cancel() {
        let copy = operatingCall
        operatingCall = nil
        copy?.cancel()
    }

    func clearIfMatches(call: OperatingCall) -> Bool {
        guard matches(call: call) else {
            return false
        }

        operatingCall = nil

        return true
    }

    func matches(call: CancellableCall) -> Bool {
        operatingCall === call
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
