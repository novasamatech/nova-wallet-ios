import Foundation
import RobinHood

final class CancellableCallStore {
    private var cancellableCall: CancellableCall?

    func store(call: CancellableCall) {
        cancellableCall = call
    }

    func clear() {
        cancellableCall = nil
    }

    func cancel() {
        let copy = cancellableCall
        cancellableCall = nil
        copy?.cancel()
    }

    func clearIfMatches(call: CancellableCall) -> Bool {
        guard cancellableCall === call else {
            return false
        }

        cancellableCall = nil

        return true
    }
}

func executeCancellable<T>(
    wrapper: CompoundOperationWrapper<T>,
    inOperationQueue operationQueue: OperationQueue,
    backingCallIn callStore: CancellableCallStore,
    runningCallbackIn callbackQueue: DispatchQueue?,
    callbackClosure: @escaping (Result<T, Error>) -> Void
) {
    wrapper.targetOperation.completionBlock = {
        dispatchInQueueWhenPossible(callbackQueue) {
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
