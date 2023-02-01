import UIKit
import RobinHood

final class DelegationListInteractor {
    weak var presenter: DelegationListInteractorOutputProtocol!
    typealias Delegations = [AccountAddress: [GovernanceOffchainDelegation]]

    let governanceOffchainDelegationsFactory: GovernanceOffchainDelegationsFactoryProtocol
    let accountAddress: AccountAddress
    let cancellableCall: CancellableCall?
    let operationQueue: OperationQueue

    init(
        accountAddress: AccountAddress,
        governanceOffchainDelegationsFactory: GovernanceOffchainDelegationsFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.governanceOffchainDelegationsFactory = governanceOffchainDelegationsFactory
        self.accountAddress = accountAddress
        self.operationQueue = operationQueue
    }

    private func fetchDelegations() {
        let wrapper = governanceOffchainDelegationsFactory.createDelegationsFetchWrapper(for: accountAddress)
        wrapper.targetOperation.completionBlock = { [weak self] in
            guard let self = self, cancellableCall === wrapper else {
                return
            }
            do {
                let delegations = try wrapper.targetOperation.extractNoCancellableResultData()
                delegations.reduce(into: Delegations()) { result, delegation in
                    var delegations = result[delegation.delegator] ?? []
                    delegations.append(delegation)
                    result[delegation.delegator] = delegations
                }
                self.notifyPresenter(result: .success(delegations))
            } catch {
                self.notifyPresenter(result: .failure(.fetchFailed(error)))
            }
        }
    }

    private func notifyPresenter(result: Result<Delegations, DelegationListError>) {
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
