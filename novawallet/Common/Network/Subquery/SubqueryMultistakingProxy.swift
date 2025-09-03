import Foundation
import Operation_iOS

final class SubqueryMultistakingProxy: BaseFetchOperationFactory {
    let configProvider: GlobalConfigProviding
    let operationQueue: OperationQueue

    init(configProvider: GlobalConfigProviding, operationQueue: OperationQueue) {
        self.configProvider = configProvider
        self.operationQueue = operationQueue
    }
}

extension SubqueryMultistakingProxy: MultistakingOffchainOperationFactoryProtocol {
    func createWrapper(
        for request: Multistaking.OffchainRequest
    ) -> CompoundOperationWrapper<Multistaking.OffchainResponse> {
        let configWrapper = configProvider.createConfigWrapper()

        let requestWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let config = try configWrapper.targetOperation.extractNoCancellableResultData()

            let operationFactory = SubqueryMultistakingOperationFactory(url: config.multiStakingApiUrl)

            return operationFactory.createWrapper(for: request)
        }

        requestWrapper.addDependency(wrapper: configWrapper)

        return requestWrapper.insertingHead(operations: configWrapper.allOperations)
    }
}
