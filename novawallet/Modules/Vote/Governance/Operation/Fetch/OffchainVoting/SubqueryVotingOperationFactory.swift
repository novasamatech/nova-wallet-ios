import Foundation
import Operation_iOS
import SubstrateSdk

final class SubqueryVotingOperationFactory: SubqueryBaseOperationFactory {
    private func prepareCastingAndDelegatorVotesQuery(for address: AccountAddress) -> String {
        """
        {
            castingVotings(filter: { voter: {equalTo: "\(address)"}}) {
                nodes {
                    referendumId
                    standardVote
                    splitVote
                    splitAbstainVote
                }
            }

            delegatorVotings(filter: {delegator: {equalTo: "\(address)"}}) {
                nodes {
                    vote
                    parent {
                        referendumId
                        voter
                        standardVote
                    }
                }
            }
        }
        """
    }

    private func prepareAllVotingActityQuery(for address: AccountAddress) -> String {
        """
        {
            castingVotings(filter: { voter: {equalTo: "\(address)"}}) {
                nodes {
                    referendumId
                    standardVote
                    splitVote
                    splitAbstainVote
                }
            }
        }
        """
    }

    private func prepareBoundedVotingActivityQuery(
        for address: AccountAddress,
        from block: BlockNumber
    ) -> String {
        """
        {
            castingVotings(filter: { voter: {equalTo: "\(address)"}, at: {greaterThanOrEqualTo: \(block)}}) {
                nodes {
                    referendumId
                    standardVote
                    splitVote
                    splitAbstainVote
                }
            }
        }
        """
    }

    private func prepareReferendumVotersWithDelegatorsQuery(referendumId: ReferendumIdLocal, isAye: Bool) -> String {
        """
        {
            castingVotings (filter: {
                referendumId: {equalTo: "\(referendumId)"},
                or: [
                      {splitVote: { isNull: false }},
                      {splitAbstainVote: {isNull: false}},
                      {standardVote: { contains: { aye: \(isAye)}}}
                    ]
            }) {
                nodes {
                  referendumId
                  standardVote
                  splitVote
                  splitAbstainVote
                  voter
                  delegatorVotes {
                    nodes {
                      delegator
                      vote
                    }
                  }
                }
            }
        }
        """
    }

    private func prepareSplitAbstainVotesWithDelegatorsQuery(referendumId: ReferendumIdLocal) -> String {
        """
        {
            castingVotings(
                filter: {
                    referendumId: { equalTo: "\(referendumId)" },
                    splitAbstainVote: { isNull: false }
                }
            ) {
                nodes {
                    voter
                    referendumId
                    splitAbstainVote
                    delegatorVotes {
                        nodes {
                            delegator
                            vote
                        }
                    }
                }
            }
        }
        """
    }

    private func prepareVotingActivityQuery(
        for address: AccountAddress,
        from block: BlockNumber?
    ) -> String {
        if let block = block {
            return prepareBoundedVotingActivityQuery(for: address, from: block)
        } else {
            return prepareAllVotingActityQuery(for: address)
        }
    }
}

extension SubqueryVotingOperationFactory: GovernanceOffchainVotingFactoryProtocol {
    func createAllVotesFetchOperation(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainVoting> {
        let query = prepareCastingAndDelegatorVotesQuery(for: address)

        let operation = createOperation(
            for: query
        ) { (response: SubqueryVotingResponse.CastingAndDelegatorResponse) -> GovernanceOffchainVoting in
            let voting = response.castingVotings.nodes.reduce(
                GovernanceOffchainVoting(address: address, votes: [:])
            ) { accum, castingVote in
                accum.insertingSubquery(castingVote: castingVote)
            }

            return response.delegatorVotings.nodes.reduce(voting) { accum, delegatedVote in
                accum.insertingSubquery(delegatedVote: delegatedVote)
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createDirectVotesFetchOperation(
        for address: AccountAddress,
        from block: BlockNumber?
    ) -> CompoundOperationWrapper<GovernanceOffchainVotes> {
        let query = prepareVotingActivityQuery(for: address, from: block)

        let operation = createOperation(
            for: query
        ) { (response: SubqueryVotingResponse.CastingResponse) -> GovernanceOffchainVotes in
            let voting = response.castingVotings.nodes.reduce(
                GovernanceOffchainVoting(address: address, votes: [:])
            ) { accum, castingVote in
                accum.insertingSubquery(castingVote: castingVote)
            }

            return voting.getAllDirectVotes()
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createReferendumVotesFetchOperation(
        referendumId: ReferendumIdLocal,
        votersType: ReferendumVotersType
    ) -> CompoundOperationWrapper<[ReferendumVoterLocal]> {
        let query = switch votersType {
        case .ayes:
            prepareReferendumVotersWithDelegatorsQuery(referendumId: referendumId, isAye: true)
        case .nays:
            prepareReferendumVotersWithDelegatorsQuery(referendumId: referendumId, isAye: false)
        case .abstains:
            prepareSplitAbstainVotesWithDelegatorsQuery(referendumId: referendumId)
        }

        let operation = createOperation(
            for: query
        ) { (response: SubqueryVotingResponse.ReferendumVotesResponse) -> [ReferendumVoterLocal] in
            response.castingVotings.nodes.compactMap { node in
                ReferendumVoterLocal(from: node)
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
