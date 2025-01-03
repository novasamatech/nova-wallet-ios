import Foundation
import SubstrateSdk

final class PoolStakingRecommendingValidationFactory: StakingActivityProviding {
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    init(
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
    }

    private func createNoDirectStaking(
        for params: StakingRecommendationValidationParams,
        view: ControllerBackedProtocol?,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> DataValidating {
        AsyncErrorConditionViolation(onError: {
            presentable.presentDirectAndPoolStakingConflict(from: view, locale: locale)
        }, preservesCondition: { completion in
            self.hasDirectStaking(
                for: params.accountId,
                connection: self.connection,
                runtimeProvider: self.runtimeProvider,
                operationQueue: self.operationQueue
            ) { result in
                switch result {
                case let .success(hasDirectStaking):
                    completion(!hasDirectStaking)
                case .failure:
                    completion(false)
                }
            }
        }, onProgress: params.onAsyncProgress)
    }
}

extension PoolStakingRecommendingValidationFactory: StakingRecommendationValidationFactoryProtocol {
    func createValidations(
        for params: StakingRecommendationValidationParams,
        controller: ControllerBackedProtocol?,
        balanceViewModelFactory _: BalanceViewModelFactoryProtocol,
        presentable: StakingErrorPresentable,
        locale: Locale
    ) -> [DataValidating] {
        let noDirectStaking = createNoDirectStaking(
            for: params,
            view: controller,
            presentable: presentable,
            locale: locale
        )

        return [noDirectStaking]
    }
}
