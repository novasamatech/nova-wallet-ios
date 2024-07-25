import UIKit
import SubstrateSdk
import Operation_iOS

final class DelegationReferendumVotersInteractor {
    weak var presenter: DelegationReferendumVotersInteractorOutputProtocol!

    let votersLocalWrapperFactory: ReferendumVotersLocalWrapperFactoryProtocol
    let referendumId: ReferendumIdLocal
    let operationQueue: OperationQueue
    let votersType: ReferendumVotersType

    private var cancellableCall: CancellableCall?

    init(
        referendumId: ReferendumIdLocal,
        votersType: ReferendumVotersType,
        votersLocalWrapperFactory: ReferendumVotersLocalWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.votersLocalWrapperFactory = votersLocalWrapperFactory
        self.referendumId = referendumId
        self.votersType = votersType
        self.operationQueue = operationQueue
    }

    private func fetchVoters() {
        let wrapper = votersLocalWrapperFactory.createWrapper(
            for: .init(referendumId: referendumId, votersType: votersType)
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self, self.cancellableCall === wrapper else {
                return
            }
            self.cancellableCall = nil
            do {
                let voters = try wrapper.targetOperation.extractNoCancellableResultData()
                self.notifyPresenter(result: .success(voters))
            } catch {
                self.notifyPresenter(result: .failure(.fetchFailed(error)))
            }
        }

        cancellableCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func notifyPresenter(result: Result<ReferendumVoterLocals, DelegationReferendumVotersError>) {
        DispatchQueue.main.async {
            switch result {
            case let .failure(error):
                self.presenter.didReceive(error: .fetchFailed(error))
            case let .success(data):
                self.presenter.didReceive(voters: data)
            }
        }
    }
}

extension DelegationReferendumVotersInteractor: DelegationReferendumVotersInteractorInputProtocol {
    func setup() {
        fetchVoters()
    }

    func refresh() {
        fetchVoters()
    }
}
