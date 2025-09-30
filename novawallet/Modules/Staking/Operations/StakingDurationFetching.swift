import Foundation
import Operation_iOS

protocol StakingDurationFetching {
    func fetchStakingDuration(
        operationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<StakingDuration, Error>) -> Void
    )
}

extension StakingDurationFetching {
    func fetchStakingDuration(
        operationFactory: StakingDurationOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<StakingDuration, Error>) -> Void
    ) {
        let operationWrapper = operationFactory.createDurationOperation()

        operationWrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operationWrapper.targetOperation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.unexpectedDependentResult))
                }
            }
        }

        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}
