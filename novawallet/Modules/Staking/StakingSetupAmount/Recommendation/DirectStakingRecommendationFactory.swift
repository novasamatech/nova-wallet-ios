import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol DirectStakingRecommendationFactoryProtocol: AnyObject {
    func createValidatorsRecommendationWrapper(
        for amount: BigUInt
    ) -> CompoundOperationWrapper<PreparedValidators>
}

final class DirectStakingRecommendationFactory {
    let runtimeProvider: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationFactory: ValidatorOperationFactoryProtocol
    let maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol
    let clusterLimit: Int
    let preferredValidators: [AccountId]

    init(
        runtimeProvider: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationFactory: ValidatorOperationFactoryProtocol,
        maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol,
        clusterLimit: Int = StakingConstants.targetsClusterLimit,
        preferredValidators: [AccountId]
    ) {
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.operationFactory = operationFactory
        self.maxNominationsOperationFactory = maxNominationsOperationFactory
        self.clusterLimit = clusterLimit
        self.preferredValidators = preferredValidators
    }

    private func createRecommendationOperation(
        dependingOn validatorsWrapper: CompoundOperationWrapper<ElectedAndPrefValidators>,
        maxNominationsOperation: BaseOperation<UInt32>,
        clusterLimit: Int
    ) -> BaseOperation<PreparedValidators> {
        ClosureOperation {
            let validators = try validatorsWrapper.targetOperation.extractNoCancellableResultData()
            let maxNominations = try maxNominationsOperation.extractNoCancellableResultData()

            let resultLimit = min(validators.electedValidators.count, Int(maxNominations))
            let recommendedValidators = RecommendationsComposer(
                resultSize: resultLimit,
                clusterSizeLimit: clusterLimit
            ).compose(
                from: validators.electedToSelectedValidators(),
                preferrences: validators.preferredValidators
            )

            return PreparedValidators(
                targets: recommendedValidators,
                maxTargets: resultLimit,
                electedAndPrefValidators: validators,
                recommendedValidators: recommendedValidators
            )
        }
    }
}

extension DirectStakingRecommendationFactory: DirectStakingRecommendationFactoryProtocol {
    func createValidatorsRecommendationWrapper(for amount: BigUInt) -> CompoundOperationWrapper<PreparedValidators> {
        let validatorsWrapper = operationFactory.allPreferred(for: preferredValidators)

        let maxNominationsWrapper = maxNominationsOperationFactory.createNominationsQuotaWrapper(
            for: amount,
            connection: connection,
            runtimeService: runtimeProvider
        )

        let recommendationOperation = createRecommendationOperation(
            dependingOn: validatorsWrapper,
            maxNominationsOperation: maxNominationsWrapper.targetOperation,
            clusterLimit: clusterLimit
        )

        recommendationOperation.addDependency(maxNominationsWrapper.targetOperation)
        recommendationOperation.addDependency(validatorsWrapper.targetOperation)

        let dependecies = validatorsWrapper.allOperations + maxNominationsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: recommendationOperation, dependencies: dependecies)
    }
}
