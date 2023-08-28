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

    init(
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationFactory: ValidatorOperationFactoryProtocol,
        defaultMaxNominations: Int = SubstrateConstants.maxNominations,
        clusterLimit: Int = StakingConstants.targetsClusterLimit
    ) {
        self.runtimeProvider = runtimeProvider
        self.operationFactory = operationFactory
        self.defaultMaxNominations = defaultMaxNominations
        self.clusterLimit = clusterLimit
    }

    private func createRecommendationOperation(
        dependingOn allElectedWrapper: CompoundOperationWrapper<[ElectedValidatorInfo]>,
        maxNominationsOperation: BaseOperation<Int>,
        clusterLimit: Int
    ) -> BaseOperation<PreparedValidators> {
        ClosureOperation {
            let electedValidators = try allElectedWrapper.targetOperation.extractNoCancellableResultData()
            let maxNominations = try maxNominationsOperation.extractNoCancellableResultData()

            let resultLimit = min(electedValidators.count, maxNominations)
            let recommendedValidators = RecommendationsComposer(
                resultSize: resultLimit,
                clusterSizeLimit: clusterLimit
            ).compose(from: electedValidators)

            return PreparedValidators(
                targets: recommendedValidators,
                maxTargets: resultLimit,
                electedValidators: electedValidators,
                recommendedValidators: recommendedValidators
            )
        }
    }
}

extension DirectStakingRecommendationFactory: DirectStakingRecommendationFactoryProtocol {
    func createValidatorsRecommendationWrapper() -> CompoundOperationWrapper<PreparedValidators> {
        let allElectedWrapper = operationFactory.allElectedOperation()

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
            dependingOn: allElectedWrapper,
            maxNominationsOperation: maxNominationsOperation,
            clusterLimit: clusterLimit
        )

        recommendationOperation.addDependency(maxNominationsOperation)
        recommendationOperation.addDependency(allElectedWrapper.targetOperation)

        let dependecies = allElectedWrapper.allOperations + [codingFactoryOperation, maxNominationsOperation]

        return CompoundOperationWrapper(targetOperation: recommendationOperation, dependencies: dependecies)
    }
}
