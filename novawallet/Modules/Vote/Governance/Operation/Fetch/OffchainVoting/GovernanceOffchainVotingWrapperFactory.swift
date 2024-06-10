import Foundation
import Operation_iOS
import SubstrateSdk

protocol GovernanceOffchainVotingWrapperFactoryProtocol {
    func createWrapper(
        for params: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainVotesLocal>
}

final class GovernanceOffchainVotingWrapperFactory: GovOffchainModelWrapperFactory<
    AccountAddress, GovernanceOffchainVoting
> {
    let operationFactory: GovernanceOffchainVotingFactoryProtocol

    init(
        chain: ChainModel,
        operationFactory: GovernanceOffchainVotingFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(
            chain: chain,
            identityParams: .init(proxyFactory: identityProxyFactory) { voting in
                Array(voting.getAllDelegates())
            }
        )
    }

    override func createModelWrapper(
        for params: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainVoting> {
        operationFactory.createAllVotesFetchOperation(for: params)
    }
}

extension GovernanceOffchainVotingWrapperFactory: GovernanceOffchainVotingWrapperFactoryProtocol {}
