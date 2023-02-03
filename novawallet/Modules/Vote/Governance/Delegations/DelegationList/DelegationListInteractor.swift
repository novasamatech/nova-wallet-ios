import UIKit
import SubstrateSdk
import RobinHood

final class DelegationListInteractor {
    weak var presenter: DelegationListInteractorOutputProtocol!

    let delegationsLocalWrapperFactoryProtocol: GovernanceDelegationsLocalWrapperFactoryProtocol
    let accountAddress: AccountAddress
    let chain: ChainModel
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    private var cancellableCall: CancellableCall?

    init(
        accountAddress: AccountAddress,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        delegationsLocalWrapperFactoryProtocol: GovernanceDelegationsLocalWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.delegationsLocalWrapperFactoryProtocol = delegationsLocalWrapperFactoryProtocol
        self.accountAddress = accountAddress
        self.chain = chain
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }

    private func fetchDelegations() {
        let wrapper = delegationsLocalWrapperFactoryProtocol.createWrapper(
            for: accountAddress,
            chain: chain,
            connection: connection,
            runtimeService: runtimeService
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
