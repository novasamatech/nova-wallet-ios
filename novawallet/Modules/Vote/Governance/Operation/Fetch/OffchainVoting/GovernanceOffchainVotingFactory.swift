import Foundation
import RobinHood

typealias GovernanceOffchainVotes = [ReferendumIdLocal: ReferendumAccountVoteLocal]

protocol GovernanceOffchainVotingFactoryProtocol {
    func createAllVotesFetchOperation(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainVoting>

    func createDirectVotesFetchOperation(
        for address: AccountAddress,
        from block: BlockNumber?
    ) -> CompoundOperationWrapper<GovernanceOffchainVotes>

    func createReferendumVotesFetchOperation(
        referendumId: ReferendumIdLocal,
        isAye: Bool
    ) -> CompoundOperationWrapper<[ReferendumVoterLocal]>
}
