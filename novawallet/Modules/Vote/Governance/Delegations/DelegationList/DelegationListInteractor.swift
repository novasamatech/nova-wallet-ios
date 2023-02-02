import UIKit
import RobinHood

final class DelegationListInteractor {
    weak var presenter: DelegationListInteractorOutputProtocol!
    typealias Delegations = [AccountAddress: [GovernanceOffchainDelegation]]

    let governanceOffchainDelegationsFactory: DelegationListWrapperFactoryProtocol
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
        governanceOffchainDelegationsFactory: DelegationListWrapperFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.governanceOffchainDelegationsFactory = governanceOffchainDelegationsFactory
        self.accountAddress = accountAddress
        self.chain = chain
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }

    private func fetchDelegations() {
        let wrapper = governanceOffchainDelegationsFactory.createWrapper(
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

import SubstrateSdk

typealias GovernanceOffchainDelegationsLocal = GovernanceDelegationAdditions<[GovernanceOffchainDelegation]>

protocol DelegationListWrapperFactoryProtocol {
    func createWrapper(
        for params: AccountAddress,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<GovernanceOffchainDelegationsLocal>
}

final class DelegationListWrapperFactory: GovOffchainModelWrapperFactory<
    AccountAddress, [GovernanceOffchainDelegation]
> {
    let operationFactory: GovernanceOffchainDelegationsFactoryProtocol

    init(
        operationFactory: GovernanceOffchainDelegationsFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(
            identityParams: .init(operationFactory: identityOperationFactory) { delegations in
                delegations.compactMap { try? $0.delegator.toAccountId() }
            }
        )
    }

    override func createModelWrapper(for params: AccountAddress, chain _: ChainModel) -> CompoundOperationWrapper<[GovernanceOffchainDelegation]> {
        operationFactory.createDelegationsFetchWrapper(for: params)
    }
}

extension DelegationListWrapperFactory: DelegationListWrapperFactoryProtocol {}
