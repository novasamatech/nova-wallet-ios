import Foundation

typealias GovernanceOffchainVotesLocal = GovernanceDelegationAdditions<[ReferendumIdLocal: GovernanceOffchainVoting.VoteType]>

extension GovernanceOffchainVotesLocal {
    struct Single {
        let voteType: GovernanceOffchainVoting.VoteType
        let identity: AccountIdentity?
        let metadata: GovernanceDelegateMetadataRemote?
    }

    func fetchVotes(for referendumId: ReferendumIdLocal) -> Single? {
        guard let voteType = model[referendumId] else {
            return nil
        }

        switch voteType {
        case .direct:
            return .init(voteType: voteType, identity: nil, metadata: nil)
        case let .delegated(delegateVote):
            guard let accountId = try? delegateVote.delegateAddress.toAccountId() else {
                return nil
            }

            return .init(
                voteType: voteType,
                identity: identities[accountId],
                metadata: metadata[accountId]
            )
        }
    }
}
