import SubstrateSdk
import Foundation_iOS
import Operation_iOS

typealias GovernanceOffchainDelegationsLocal = GovernanceDelegationAdditions<[GovernanceOffchainDelegation]>

protocol GovernanceDelegationsLocalWrapperFactoryProtocol {
    func createWrapper(
        for params: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainDelegationsLocal>
}

final class GovernanceDelegationsLocalWrapperFactory: GovOffchainModelWrapperFactory<
    AccountAddress, [GovernanceOffchainDelegation]
> {
    let operationFactory: GovernanceOffchainDelegationsFactoryProtocol

    init(
        chain: ChainModel,
        operationFactory: GovernanceOffchainDelegationsFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(
            chain: chain,
            identityParams: .init(proxyFactory: identityProxyFactory) { delegations in
                delegations.compactMap { try? $0.delegator.toAccountId() }
            }
        )
    }

    override func createModelWrapper(
        for params: AccountAddress
    ) -> CompoundOperationWrapper<[GovernanceOffchainDelegation]> {
        operationFactory.createDelegationsFetchWrapper(for: params)
    }
}

extension GovernanceDelegationsLocalWrapperFactory: GovernanceDelegationsLocalWrapperFactoryProtocol {}
