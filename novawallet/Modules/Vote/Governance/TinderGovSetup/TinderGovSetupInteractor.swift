import SoraFoundation
import SubstrateSdk
import Operation_iOS

final class TinderGovSetupInteractor {
    weak var presenter: TinderGovSetupInteractorOutputProtocol?

    private let repository: AnyDataProviderRepository<VotingPowerLocal>
    private let operationQueue: OperationQueue

    init(
        repository: AnyDataProviderRepository<VotingPowerLocal>,
        operationQueue: OperationQueue
    ) {
        self.repository = repository
        self.operationQueue = operationQueue
    }
}

extension TinderGovSetupInteractor: TinderGovSetupInteractorInputProtocol {
    func process(votingPower: VotingPowerLocal) {
        let saveOperation = repository.saveOperation(
            { [votingPower] },
            { [] }
        )

        execute(
            operation: saveOperation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case .success:
                self?.presenter?.didProcessVotingPower()
            case let .failure(error):
                self?.presenter?.didReceiveBaseError(.votingPowerSaveFailed(error))
            }
        }
    }
}
