import Foundation
import RobinHood

final class AsyncClosureOperation<ResultType>: BaseOperation<ResultType> {
    let operationClosure: (@escaping (Result<ResultType, Error>?) -> Void) throws -> Void
    let cancelationClosure: () -> Void

    private var mutex: DispatchSemaphore?

    public init(
        cancelationClosure: @escaping () -> Void,
        operationClosure: @escaping (@escaping (Result<ResultType, Error>?) -> Void) throws -> Void
    ) {
        self.cancelationClosure = cancelationClosure
        self.operationClosure = operationClosure
    }

    override public func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        mutex = DispatchSemaphore(value: 0)

        do {
            var closureResult: Result<ResultType, Error>?

            try operationClosure { [weak self] operationResult in
                closureResult = operationResult

                self?.mutex?.signal()
            }

            if let result = closureResult {
                self.result = result
            } else {
                mutex?.wait()

                result = closureResult
            }

        } catch {
            result = .failure(error)
        }
    }

    override func cancel() {
        super.cancel()

        cancelationClosure()
    }
}
