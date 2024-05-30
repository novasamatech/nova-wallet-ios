import UIKit
import SubstrateSdk
import RobinHood

final class DelegationListInteractor {
    weak var presenter: DelegationListInteractorOutputProtocol!

    let delegationsLocalWrapperFactoryProtocol: GovernanceDelegationsLocalWrapperFactoryProtocol
    let accountAddress: AccountAddress
    let operationQueue: OperationQueue
    private var cancellableCall: CancellableCall?

    init(
        accountAddress: AccountAddress,
        delegationsLocalWrapperFactoryProtocol: GovernanceDelegationsLocalWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.delegationsLocalWrapperFactoryProtocol = delegationsLocalWrapperFactoryProtocol
        self.accountAddress = accountAddress
        self.operationQueue = operationQueue
    }

    private func fetchDelegations() {
        let wrapper = delegationsLocalWrapperFactoryProtocol.createWrapper(
            for: accountAddress
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self, self.cancellableCall === wrapper else {
                return
            }
            self.cancellableCall = nil
            do {
                let delegations = try wrapper.targetOperation.extractNoCancellableResultData()
                self.notifyPresenter(result: .success(delegations))
            } catch {
                self.notifyPresenter(result: .failure(.fetchFailed(error)))
            }
        }

        cancellableCall = wrapper
        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func notifyPresenter(result: Result<GovernanceOffchainDelegationsLocal, DelegationListError>) {
        DispatchQueue.main.async {
            switch result {
            case let .failure(error):
                self.presenter.didReceive(error: .fetchFailed(error))
            case let .success(data):
                self.presenter.didReceive(delegations: data)
            }
        }
    }
}

extension DelegationListInteractor: DelegationListInteractorInputProtocol {
    func setup() {
        fetchDelegations()
    }

    func refresh() {
        fetchDelegations()
    }
}
