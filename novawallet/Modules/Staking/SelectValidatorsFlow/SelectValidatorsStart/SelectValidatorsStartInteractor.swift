import UIKit
import RobinHood
import SubstrateSdk
import IrohaCrypto
import BigInt

final class SelectValidatorsStartInteractor: RuntimeConstantFetching {
    weak var presenter: SelectValidatorsStartInteractorOutputProtocol!

    let operationFactory: ValidatorOperationFactoryProtocol
    let maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol
    let operationQueue: OperationQueue
    let runtimeService: RuntimeCodingServiceProtocol
    let connection: JSONRPCEngine
    let preferredValidators: [AccountId]
    let stakingAmount: BigUInt

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine,
        operationFactory: ValidatorOperationFactoryProtocol,
        maxNominationsOperationFactory: MaxNominationsOperationFactoryProtocol,
        operationQueue: OperationQueue,
        preferredValidators: [AccountId],
        stakingAmount: BigUInt
    ) {
        self.runtimeService = runtimeService
        self.connection = connection
        self.operationFactory = operationFactory
        self.maxNominationsOperationFactory = maxNominationsOperationFactory
        self.operationQueue = operationQueue
        self.preferredValidators = preferredValidators
        self.stakingAmount = stakingAmount
    }

    private func prepareRecommendedValidatorList() {
        let wrapper = operationFactory.allPreferred(for: preferredValidators)

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let validators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceiveValidators(result: .success(validators))
                } catch {
                    self?.presenter.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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
            self?.presenter.didReceiveMaxNominations(result: result)
        }
    }
}

extension SelectValidatorsStartInteractor: SelectValidatorsStartInteractorInputProtocol {
    func setup() {
        prepareRecommendedValidatorList()
        provideMaxNominations()
    }
}
