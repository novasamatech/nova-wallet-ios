import SubstrateSdk
import Foundation_iOS
import Operation_iOS

typealias ReferendumVoterLocals = GovernanceDelegationAdditions<[ReferendumVoterLocal]>

struct ReferendumVotersFactoryParams {
    let referendumId: ReferendumIdLocal
    let votersType: ReferendumVotersType
}

protocol ReferendumVotersLocalWrapperFactoryProtocol {
    func createWrapper(
        for params: ReferendumVotersFactoryParams
    ) -> CompoundOperationWrapper<ReferendumVoterLocals>
}

final class ReferendumVotersLocalWrapperFactory: GovOffchainModelWrapperFactory<
    ReferendumVotersFactoryParams,
    [ReferendumVoterLocal]
>,
    ReferendumVotersLocalWrapperFactoryProtocol {
    let operationFactory: GovernanceOffchainVotingFactoryProtocol

    init(
        chain: ChainModel,
        operationFactory: GovernanceOffchainVotingFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        metadataOperationFactory: GovernanceDelegateMetadataFactoryProtocol
    ) {
        self.operationFactory = operationFactory

        super.init(
            chain: chain,
            identityParams: .init(
                proxyFactory: identityProxyFactory,
                closure: Self.mapAccounts
            ),
            metadataParams: .init(
                operationFactory: metadataOperationFactory,
                closure: Self.mapAccounts
            )
        )
    }

    private static func mapAccounts(from delegations: [ReferendumVoterLocal]) -> [AccountId] {
        delegations.flatMap { delegation in
            [delegation.accountId] + delegation.delegators.compactMap {
                try? $0.delegator.toAccountId()
            }
        }
    }

    override func createModelWrapper(
        for params: ReferendumVotersFactoryParams
    ) -> CompoundOperationWrapper<[ReferendumVoterLocal]> {
        operationFactory.createReferendumVotesFetchOperation(
            referendumId: params.referendumId,
            votersType: params.votersType
        )
    }
}
