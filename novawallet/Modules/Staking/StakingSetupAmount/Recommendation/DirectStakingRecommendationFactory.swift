import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

protocol DirectStakingRecommendationFactoryProtocol: AnyObject {
    func createValidatorsRecommendationWrapper(
        for amount: BigUInt
    ) -> CompoundOperationWrapper<PreparedValidators>
}

final class DirectStakingRecommendationFactory {
    let chain: ChainModel
    let runtimeProvider: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let operationFactory: ValidatorOperationFactoryProtocol
    let maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol
    let clusterLimit: Int
    let preferredValidatorsProvider: PreferredValidatorsProviding
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        runtimeProvider: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationFactory: ValidatorOperationFactoryProtocol,
        maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol,
        clusterLimit: Int = StakingConstants.targetsClusterLimit,
        preferredValidatorsProvider: PreferredValidatorsProviding,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.runtimeProvider = runtimeProvider
        self.connection = connection
        self.operationFactory = operationFactory
        self.maxNominationsOperationFactory = maxNominationsOperationFactory
        self.clusterLimit = clusterLimit
        self.preferredValidatorsProvider = preferredValidatorsProvider
        self.operationQueue = operationQueue
    }

    private func createRecommendationOperation(
        dependingOn validatorsWrapper: CompoundOperationWrapper<ElectedAndPrefValidators>,
        maxNominationsOperation: BaseOperation<UInt32>,
        clusterLimit: Int
    ) -> BaseOperation<PreparedValidators> {
        ClosureOperation {
            let validators = try validatorsWrapper.targetOperation.extractNoCancellableResultData()
            let maxNominations = try maxNominationsOperation.extractNoCancellableResultData()

            let resultLimit = min(validators.notExcludedElectedValidators.count, Int(maxNominations))
            let recommendedValidators = RecommendationsComposer(
                resultSize: resultLimit,
                clusterSizeLimit: clusterLimit
            ).compose(
                from: validators.notExcludedElectedToSelectedValidators(),
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
        let preferredValidatorsWrapper = preferredValidatorsProvider.createPreferredValidatorsWrapper(for: chain)

        let validatorsWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let preferredValidators = try preferredValidatorsWrapper.targetOperation.extractNoCancellableResultData()

            return self.operationFactory.allPreferred(for: preferredValidators)
        }

        validatorsWrapper.addDependency(wrapper: preferredValidatorsWrapper)

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

        let dependecies = preferredValidatorsWrapper.allOperations + validatorsWrapper.allOperations +
            maxNominationsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: recommendationOperation, dependencies: dependecies)
    }
}
