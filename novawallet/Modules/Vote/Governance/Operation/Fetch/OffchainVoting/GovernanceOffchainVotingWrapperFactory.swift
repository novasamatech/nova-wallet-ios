import Foundation
import RobinHood
import SubstrateSdk

protocol GovernanceOffchainVotingWrapperFactoryProtocol {
    func createWrapper(
        for params: AccountAddress,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<GovernanceOffchainVotesLocal>
}

final class GovernanceOffchainVotingWrapperFactory: GovOffchainModelWrapperFactory<
    AccountAddress, GovernanceOffchainVoting
> {
    let operationFactory: GovernanceOffchainVotingFactoryProtocol

    init(
        operationFactory: GovernanceOffchainVotingFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(
            identityParams: .init(operationFactory: identityOperationFactory) { voting in
                Array(voting.getAllDelegates())
            }
        )
    }

    override func createModelWrapper(
        for params: AccountAddress,
        chain _: ChainModel
    ) -> CompoundOperationWrapper<GovernanceOffchainVoting> {
        operationFactory.createAllVotesFetchOperation(for: params)
    }
}

extension GovernanceOffchainVotingWrapperFactory: GovernanceOffchainVotingWrapperFactoryProtocol {}
