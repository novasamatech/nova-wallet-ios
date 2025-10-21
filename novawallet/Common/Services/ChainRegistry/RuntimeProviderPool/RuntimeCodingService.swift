import Foundation
import Operation_iOS

protocol RuntimeCodingServiceProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>
}

extension RuntimeCodingServiceProtocol {
    func fetchCoderFactory(
        runningIn queue: OperationQueue,
        completion successClosure: @escaping (RuntimeCoderFactoryProtocol) -> Void,
        errorClosure: @escaping (Error) -> Void
    ) {
        let operation = fetchCoderFactoryOperation()

        execute(
            operation: operation,
            inOperationQueue: queue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case let .success(factory):
                successClosure(factory)
            case let .failure(error):
                errorClosure(error)
            }
        }
    }
}
