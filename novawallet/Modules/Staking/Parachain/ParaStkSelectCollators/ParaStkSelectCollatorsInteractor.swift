import UIKit

final class ParaStkSelectCollatorsInteractor {
    weak var presenter: ParaStkSelectCollatorsInteractorOutputProtocol?

    let chain: ChainModel
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardService: ParaStakingRewardCalculatorServiceProtocol
    let connection: ChainConnection
    let runtimeProvider: RuntimeProviderProtocol
    let collatorOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        collatorOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.collatorService = collatorService
        self.rewardService = rewardService
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.collatorOperationFactory = collatorOperationFactory
        self.operationQueue = operationQueue
    }

    private func provideElectedCollatorsInfo() {
        let wrapper = collatorOperationFactory.electedCollatorsInfoOperation(
            for: collatorService,
            rewardService: rewardService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            chainFormat: chain.chainFormat
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let electedCollators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveCollators(result: .success(electedCollators))
                } catch {
                    self?.presenter?.didReceiveCollators(result: .failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension ParaStkSelectCollatorsInteractor: ParaStkSelectCollatorsInteractorInputProtocol {
    func setup() {
        provideElectedCollatorsInfo()
    }
}
