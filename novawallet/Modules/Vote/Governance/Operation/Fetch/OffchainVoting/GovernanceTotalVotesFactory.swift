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

        let operation = createOperation(
            for: query
        ) { [weak self] (response: SubqueryVotingResponse.ReferendumVotesResponse) -> ReferendumVotingAmount in
            response.castingVotings.nodes
                .compactMap { ReferendumVoterLocal(from: $0) }
                .reduce(
                    ReferendumVotingAmount(
                        aye: 0,
                        nay: 0,
                        abstain: 0
                    )
                ) { self?.sum($0, with: $1) ?? $0 }
        }

        return operation
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
