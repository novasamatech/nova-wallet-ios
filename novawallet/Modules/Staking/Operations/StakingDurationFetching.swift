import Foundation
import Operation_iOS

protocol StakingDurationFetching {
    func fetchStakingDuration(
        operationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<StakingDuration, Error>) -> Void
    )
}

extension StakingDurationFetching {
    func fetchStakingDuration(
        operationFactory: StakingDurationOperationFactoryProtocol,
        operationQueue: OperationQueue,
        closure: @escaping (Result<StakingDuration, Error>) -> Void
    ) {
        let operationWrapper = operationFactory.createDurationOperation()

        execute(
            wrapper: operationWrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main,
            callbackClosure: closure
        )
    }
}
