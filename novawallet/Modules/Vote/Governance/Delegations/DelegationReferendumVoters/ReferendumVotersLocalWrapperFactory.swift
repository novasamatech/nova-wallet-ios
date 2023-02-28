import SubstrateSdk
import SoraFoundation
import RobinHood

typealias ReferendumVoterLocals = GovernanceDelegationAdditions<[ReferendumVoterLocal]>

struct ReferendumVotersFactoryParams {
    let referendumId: ReferendumIdLocal
    let isAye: Bool
}

protocol ReferendumVotersLocalWrapperFactoryProtocol {
    func createWrapper(
        for params: ReferendumVotersFactoryParams,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ReferendumVoterLocals>
}

final class ReferendumVotersLocalWrapperFactory: GovOffchainModelWrapperFactory<ReferendumVotersFactoryParams, [ReferendumVoterLocal]>,
                                                 ReferendumVotersLocalWrapperFactoryProtocol {
    let operationFactory: GovernanceOffchainVotingFactoryProtocol

    init(
        operationFactory: GovernanceOffchainVotingFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(
            identityParams: .init(operationFactory: identityOperationFactory) { delegations in
                delegations.flatMap { delegation in
                    [delegation.accountId] + delegation.delegators.compactMap {
                        try? $0.delegator.toAccountId()
                    }
                }
            },
            metadataParams: .init(operationFactory: metadataOperationFactory) { delegations in
                delegations.flatMap { delegation in
                    [delegation.accountId] + delegation.delegators.compactMap {
                        try? $0.delegator.toAccountId()
                    }
                }
            }
        )
    }

    override func createModelWrapper(
        for params: ReferendumVotersFactoryParams,
        chain _: ChainModel
    ) -> CompoundOperationWrapper<[ReferendumVoterLocal]> {
        operationFactory.createReferendumVotesFetchOperation(
            referendumId: params.referendumId,
            isAye: params.isAye
        )
    }
}
