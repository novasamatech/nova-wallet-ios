import Foundation
import Operation_iOS

public final class BackendAttestationExchangeGate {
    private struct Waiter {
        let owner: AnyObject
        let onGranted: () -> Void
    }

    private let operationQueue: OperationQueue
    private let mutex = NSLock()

    private var holder: AnyObject?
    private var waiters: [Waiter] = []

    public init(operationQueue: OperationQueue) {
        self.operationQueue = operationQueue
    }

    public func createExclusiveWrapper<T>(
        _ exchangeClosure: @escaping () throws -> CompoundOperationWrapper<T>
    ) -> CompoundOperationWrapper<T> {
        CompoundOperationWrapper(
            targetOperation: BackendAttestationExclusiveOperation(
                gate: self,
                operationQueue: operationQueue,
                exchangeClosure: exchangeClosure
            )
        )
    }
}

private extension BackendAttestationExchangeGate {
    func enter(_ owner: AnyObject, onGranted: @escaping () -> Void) {
        mutex.lock()

        guard holder == nil else {
            waiters.append(Waiter(owner: owner, onGranted: onGranted))
            mutex.unlock()

            return
        }

        holder = owner
        mutex.unlock()

        onGranted()
    }

    func withdraw(_ owner: AnyObject) {
        mutex.lock()
        waiters.removeAll { $0.owner === owner }
        mutex.unlock()
    }

    func leave(_ owner: AnyObject) {
        mutex.lock()

        guard holder === owner else {
            mutex.unlock()

            return
        }

        let next = waiters.isEmpty ? nil : waiters.removeFirst()
        holder = next?.owner

        mutex.unlock()

        next?.onGranted()
    }
}

private final class BackendAttestationExclusiveOperation<T>: BaseOperation<T> {
    private let gate: BackendAttestationExchangeGate
    private let operationQueue: OperationQueue
    private let exchangeClosure: () throws -> CompoundOperationWrapper<T>

    init(
        gate: BackendAttestationExchangeGate,
        operationQueue: OperationQueue,
        exchangeClosure: @escaping () throws -> CompoundOperationWrapper<T>
    ) {
        self.gate = gate
        self.operationQueue = operationQueue
        self.exchangeClosure = exchangeClosure
    }

    override func performAsync(_ callback: @escaping (Result<T, Error>) -> Void) throws {
        gate.enter(self) { [self] in
            run(callback: callback)
        }
    }

    override func cancel() {
        super.cancel()

        gate.withdraw(self)
    }

    private func run(callback: @escaping (Result<T, Error>) -> Void) {
        guard !isCancelled else {
            gate.leave(self)
            callback(.failure(BaseOperationError.parentOperationCancelled))

            return
        }

        let wrapper: CompoundOperationWrapper<T>

        do {
            wrapper = try exchangeClosure()
        } catch {
            gate.leave(self)
            callback(.failure(error))

            return
        }

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [self] result in
            gate.leave(self)
            callback(result)
        }
    }
}
