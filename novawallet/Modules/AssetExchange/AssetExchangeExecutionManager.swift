import Foundation
import Operation_iOS

protocol AssetExchangeExecutionManagerProtocol {
    func executeSwap(for amountIn: Balance, completion: @escaping (Result<Balance, Error>) -> Void)
}

final class AssetExchangeExecutionManager {
    let operations: [AssetExchangeAtomicOperationProtocol]
    let operationQueue: OperationQueue

    init(operations: [AssetExchangeAtomicOperationProtocol], operationQueue: OperationQueue) {
        self.operations = operations
        self.operationQueue = operationQueue
    }
}

extension AssetExchangeExecutionManager: AssetExchangeExecutionManagerProtocol {
    func executeSwap(for amountIn: Balance, completion: @escaping (Result<Balance, Error>) -> Void) {
        let wrappers: [CompoundOperationWrapper<Balance>] = operations.reduce([]) { prevWrappers, operation in
            let prevWrapper = prevWrappers.last
            let amountClosure: () throws -> Balance = {
                try prevWrapper.map { try $0.targetOperation.extractNoCancellableResultData() } ?? amountIn
            }

            let nextWrapper = operation.executeWrapper(for: amountClosure)

            return prevWrappers + [nextWrapper]
        }

        guard let firstWrapper = wrappers.first else { return }

        let totalWrapper: CompoundOperationWrapper<Balance> = wrappers
            .suffix(wrappers.count - 1)
            .reduce(firstWrapper) { totalWrapper, nextWrapper in
                nextWrapper.addDependency(operations: [totalWrapper.targetOperation])

                return nextWrapper.insertingHead(operations: totalWrapper.allOperations)
            }

        execute(
            wrapper: totalWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { result in
            switch result {
            case let .success(balance):
                completion(.success(balance))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}
