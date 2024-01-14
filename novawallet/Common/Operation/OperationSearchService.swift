import Foundation
import RobinHood

final class OperationSearchService<P, R>: Longrunable {
    typealias ResultType = P

    let paramsClosure: () throws -> [P]
    let fetchFactory: (P) -> CompoundOperationWrapper<R>
    let evalClosure: (R) -> Bool
    let operationQueue: OperationQueue
    let workingQueue: DispatchQueue

    private var cancellableStore = CancellableCallStore()

    init(
        paramsClosure: @escaping () throws -> [P],
        fetchFactory: @escaping (P) -> CompoundOperationWrapper<R>,
        evalClosure: @escaping (R) -> Bool,
        operationQueue: OperationQueue,
        workingQueue: DispatchQueue = DispatchQueue.global()
    ) {
        self.paramsClosure = paramsClosure
        self.fetchFactory = fetchFactory
        self.evalClosure = evalClosure
        self.operationQueue = operationQueue
        self.workingQueue = workingQueue
    }

    private func handle(
        result: Result<R, Error>,
        params: [P],
        start: Int,
        end: Int,
        completionClosure: @escaping (Result<P, Error>) -> Void
    ) {
        switch result {
        case let .success(value):
            let evalResult = evalClosure(value)

            let midIndex = (start + end) / 2
            if evalResult {
                search(
                    for: params,
                    start: midIndex + 1,
                    end: end,
                    completionClosure: completionClosure
                )
            } else {
                search(
                    for: params,
                    start: start,
                    end: midIndex,
                    completionClosure: completionClosure
                )
            }
        case let .failure(error):
            completionClosure(.failure(error))
        }
    }

    private func search(
        for params: [P],
        start: Int,
        end: Int,
        completionClosure: @escaping (Result<P, Error>) -> Void
    ) {
        guard start < end else {
            if start < params.count {
                completionClosure(.success(params[start]))
            } else {
                completionClosure(.failure(CommonError.dataCorruption))
            }

            return
        }

        let midIndex = (start + end) / 2

        let wrapper = fetchFactory(params[midIndex])

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: cancellableStore,
            runningCallbackIn: workingQueue
        ) { result in
            self.handle(
                result: result,
                params: params,
                start: start,
                end: end,
                completionClosure: completionClosure
            )
        }
    }

    func start(with completionClosure: @escaping (Result<P, Error>) -> Void) {
        do {
            let params = try paramsClosure()

            search(for: params, start: 0, end: params.count - 1, completionClosure: completionClosure)
        } catch {
            completionClosure(.failure(error))
        }
    }

    func cancel() {
        cancellableStore.cancel()
    }
}
