import UIKit
import Operation_iOS
import SubstrateSdk
import NovaCrypto
import BigInt

final class SelectValidatorsStartInteractor: RuntimeConstantFetching {
    weak var presenter: SelectValidatorsStartInteractorOutputProtocol?

    let chain: ChainModel
    let operationFactory: ValidatorOperationFactoryProtocol
    let maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol
    let operationQueue: OperationQueue
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let preferredValidatorsProvider: PreferredValidatorsProviding
    let stakingAmount: BigUInt

    init(
        chain: ChainModel,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationFactory: ValidatorOperationFactoryProtocol,
        maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol,
        operationQueue: OperationQueue,
        preferredValidatorsProvider: PreferredValidatorsProviding,
        stakingAmount: BigUInt
    ) {
        self.chain = chain
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationFactory = operationFactory
        self.maxNominationsOperationFactory = maxNominationsOperationFactory
        self.operationQueue = operationQueue
        self.preferredValidatorsProvider = preferredValidatorsProvider
        self.stakingAmount = stakingAmount
    }

    private func prepareRecommendedValidatorList() {
        let preferredValidatorsWrapper = preferredValidatorsProvider.createPreferredValidatorsWrapper(
            for: chain
        )

        let remoteFetchWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            let preferredValidators = try preferredValidatorsWrapper.targetOperation.extractNoCancellableResultData()

            return self.operationFactory.allPreferred(for: preferredValidators)
        }

        remoteFetchWrapper.addDependency(wrapper: preferredValidatorsWrapper)

        let wrapper = remoteFetchWrapper.insertingHead(operations: preferredValidatorsWrapper.allOperations)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceiveValidators(result: result)
        }
    }

    private func provideMaxNominations() {
        let wrapper = maxNominationsOperationFactory.createNominationsQuotaWrapper(
            for: stakingAmount,
            connection: connection,
            runtimeService: runtimeService
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceiveMaxNominations(result: result)
        }
    }
}

extension SelectValidatorsStartInteractor: SelectValidatorsStartInteractorInputProtocol {
    func setup() {
        prepareRecommendedValidatorList()
        provideMaxNominations()
    }
}
