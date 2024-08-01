import Foundation
import Operation_iOS
import BigInt

struct ReferendumVotingAmount {
    let aye: BigUInt
    let nay: BigUInt
    let abstain: BigUInt
}

protocol GovernanceTotalVotesFactoryProtocol {
    func createOperation(
        referendumId: ReferendumIdLocal,
        votersType: ReferendumVotersType?
    ) -> BaseOperation<ReferendumVotingAmount>
}

final class GovernanceTotalVotesFactory: SubqueryBaseOperationFactory {
    private func prepareSplitAbstainVotesQuery(referendumId: ReferendumIdLocal) -> String {
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
                }
            }
        }
        """
    }

    private func prepareStandardVotesQuery(referendumId: ReferendumIdLocal, isAye: Bool) -> String {
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
                    voters
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

    private func prepareAllVotesQuery(referendumId: ReferendumIdLocal) -> String {
        """
        {
            castingVotings(
                filter: {
                    referendumId: { equalTo: "\(referendumId)" }
                }
            ) {
                nodes {
                    referendumId
                    voter
                    splitVote
                    splitAbstainVote
                    standardVote
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
}

extension GovernanceTotalVotesFactory: GovernanceTotalVotesFactoryProtocol {
    func createOperation(referendumId: ReferendumIdLocal, votersType: ReferendumVotersType?) -> BaseOperation<ReferendumVotingAmount> {
        let query = if let votersType {
            switch votersType {
            case .ayes:
                prepareStandardVotesQuery(referendumId: referendumId, isAye: true)
            case .nays:
                prepareStandardVotesQuery(referendumId: referendumId, isAye: false)
            case .abstains:
                prepareSplitAbstainVotesQuery(referendumId: referendumId)
            }

        } else {
            prepareAllVotesQuery(referendumId: referendumId)
        }

        let operation = if votersType == .abstains {
            createOperation(for: query, resultHandler: mapAbstainVotingResponse)
        } else {
            createOperation(for: query, resultHandler: mapVotingResponse)
        }

        return operation
    }

    private func mapAbstainVotingResponse(_ response: SubqueryVotingResponse.CastingResponse) -> ReferendumVotingAmount {
        mapAmount(
            from: response.castingVotings.nodes.compactMap { ReferendumVoterLocal(from: $0) }
        )
    }

    private func mapVotingResponse(_ response: SubqueryVotingResponse.ReferendumVotesResponse) -> ReferendumVotingAmount {
        mapAmount(
            from: response.castingVotings.nodes.compactMap { ReferendumVoterLocal(from: $0) }
        )
    }

    private func mapAmount(from voters: [ReferendumVoterLocal]) -> ReferendumVotingAmount {
        voters.reduce(
            ReferendumVotingAmount(
                aye: 0,
                nay: 0,
                abstain: 0
            )
        ) { sum($0, with: $1) }
    }

    private func sum(
        _ amount: ReferendumVotingAmount,
        with voter: ReferendumVoterLocal
    ) -> ReferendumVotingAmount {
        var accAye = amount.aye
        var accNay = amount.nay
        var accAbstain = amount.abstain

        switch voter.vote {
        case .split:
            accAye += voter.vote.ayes
            accNay += voter.vote.nays
        case .splitAbstain:
            accAbstain += voter.vote.abstains
        case let .standard(model) where model.vote.aye:
            accAye += (voter.vote.ayes + voter.delegatorsVotes)
        case let .standard(model):
            accNay += (voter.vote.nays + voter.delegatorsVotes)
        }

        return ReferendumVotingAmount(
            aye: accAye,
            nay: accNay,
            abstain: accAbstain
        )
    }
}
