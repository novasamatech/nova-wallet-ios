import SubstrateSdk
import SoraFoundation
import RobinHood

typealias GovernanceOffchainDelegationsLocal = GovernanceDelegationAdditions<[GovernanceOffchainDelegation]>

protocol GovernanceDelegationsLocalWrapperFactoryProtocol {
    func createWrapper(
        for params: AccountAddress,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<GovernanceOffchainDelegationsLocal>
}

final class GovernanceDelegationsLocalWrapperFactory: GovOffchainModelWrapperFactory<
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

    override func createModelWrapper(
        for params: AccountAddress,
        chain _: ChainModel
    ) -> CompoundOperationWrapper<[GovernanceOffchainDelegation]> {
        operationFactory.createDelegationsFetchWrapper(for: params)
    }
}

extension GovernanceDelegationsLocalWrapperFactory: GovernanceDelegationsLocalWrapperFactoryProtocol {}
