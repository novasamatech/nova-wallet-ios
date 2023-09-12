import Foundation
import RobinHood

protocol DirectStakingRecommendationFactoryProtocol: AnyObject {
    func createValidatorsRecommendationWrapper() -> CompoundOperationWrapper<PreparedValidators>
}

final class DirectStakingRecommendationFactory {
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationFactory: ValidatorOperationFactoryProtocol
    let defaultMaxNominations: Int
    let clusterLimit: Int
    let preferredValidators: [AccountId]

    init(
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationFactory: ValidatorOperationFactoryProtocol,
        defaultMaxNominations: Int = SubstrateConstants.maxNominations,
        clusterLimit: Int = StakingConstants.targetsClusterLimit,
        preferredValidators: [AccountId]
    ) {
        self.runtimeProvider = runtimeProvider
        self.operationFactory = operationFactory
        self.defaultMaxNominations = defaultMaxNominations
        self.clusterLimit = clusterLimit
        self.preferredValidators = preferredValidators
    }

    private func createRecommendationOperation(
        dependingOn validatorsWrapper: CompoundOperationWrapper<ElectedAndPrefValidators>,
        maxNominationsOperation: BaseOperation<Int>,
        clusterLimit: Int
    ) -> BaseOperation<PreparedValidators> {
        ClosureOperation {
            let validators = try validatorsWrapper.targetOperation.extractNoCancellableResultData()
            let maxNominations = try maxNominationsOperation.extractNoCancellableResultData()

            let resultLimit = min(validators.electedValidators.count, maxNominations)
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
    func createValidatorsRecommendationWrapper() -> CompoundOperationWrapper<PreparedValidators> {
        let validatorsWrapper = operationFactory.allPreferred(for: preferredValidators)

        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()
        let maxNominationsOperation = PrimitiveConstantOperation(
            path: .maxNominations,
            fallbackValue: defaultMaxNominations
        )

        maxNominationsOperation.configurationBlock = {
            do {
                maxNominationsOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                maxNominationsOperation.result = .failure(error)
            }
        }

        maxNominationsOperation.addDependency(codingFactoryOperation)

        let recommendationOperation = createRecommendationOperation(
            dependingOn: validatorsWrapper,
            maxNominationsOperation: maxNominationsOperation,
            clusterLimit: clusterLimit
        )

        recommendationOperation.addDependency(maxNominationsOperation)
        recommendationOperation.addDependency(validatorsWrapper.targetOperation)

        let dependecies = validatorsWrapper.allOperations + [codingFactoryOperation, maxNominationsOperation]

        return CompoundOperationWrapper(targetOperation: recommendationOperation, dependencies: dependecies)
    }
}
