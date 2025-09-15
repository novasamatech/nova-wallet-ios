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
    func createOperation(
        referendumId: ReferendumIdLocal,
        votersType: ReferendumVotersType?
    ) -> BaseOperation<ReferendumVotingAmount> {
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

        return createOperation(
            for: query,
            resultHandler: mapVotingResponse
        )
    }

    private func mapVotingResponse(_ response: CastingResponse) -> ReferendumVotingAmount {
        response.castingVotings.nodes
            .compactMap { voting -> LocalVotingMapping? in
                guard let vote = createVoteLocal(from: voting) else { return nil }

                return LocalVotingMapping(
                    vote: vote,
                    delegatorsVotes: delegatorsVoteAmount(from: voting.delegatorVotes)
                )
            }
            .reduce(
                ReferendumVotingAmount(
                    aye: 0,
                    nay: 0,
                    abstain: 0
                )
            ) { sum($0, with: $1) }
    }

    private func delegatorsVoteAmount(from response: DelegatorVotesReponse?) -> BigUInt {
        response?
            .nodes
            .compactMap { createDelegator(from: $0) }
            .reduce(into: 0) {
                $0 += ($1.power.conviction.votes(for: $1.power.balance) ?? 0)
            } ?? 0
    }

    private func createVoteLocal(
        from castingVote: CastingVoting
    ) -> ReferendumAccountVoteLocal? {
        if let standardVote = castingVote.standardVote {
            return ReferendumAccountVoteLocal(subqueryStandardVote: standardVote)
        } else if let splitVote = castingVote.splitVote {
            return ReferendumAccountVoteLocal(subquerySplitVote: splitVote)
        } else if let splitAbstainVote = castingVote.splitAbstainVote {
            return ReferendumAccountVoteLocal(subquerySplitAbstainVote: splitAbstainVote)
        }

        return nil
    }

    private func createDelegator(
        from node: DelegatorVotesReponse.Delegation?
    ) -> GovernanceOffchainDelegation? {
        guard let node, let delegatorBalance = BigUInt(node.vote.amount) else {
            return nil
        }

        let delegatorConviction = ConvictionVoting.Conviction(subqueryConviction: node.vote.conviction)

        let delegatorPower = GovernanceOffchainVoting.DelegatorPower(
            balance: delegatorBalance,
            conviction: delegatorConviction
        )

        return GovernanceOffchainDelegation(
            delegator: node.delegator,
            power: delegatorPower
        )
    }

    private func sum(
        _ amount: ReferendumVotingAmount,
        with voting: LocalVotingMapping
    ) -> ReferendumVotingAmount {
        var accAye = amount.aye
        var accNay = amount.nay
        var accAbstain = amount.abstain

        switch voting.vote {
        case .split:
            accAye += voting.vote.ayes
            accNay += voting.vote.nays
        case .splitAbstain:
            accAbstain += voting.vote.abstains
        case let .standard(model) where model.vote.aye:
            accAye += (voting.vote.ayes + voting.delegatorsVotes)
        case .standard:
            accNay += (voting.vote.nays + voting.delegatorsVotes)
        }

        return ReferendumVotingAmount(
            aye: accAye,
            nay: accNay,
            abstain: accAbstain
        )
    }
}

// MARK: Model

private extension GovernanceTotalVotesFactory {
    struct LocalVotingMapping {
        let vote: ReferendumAccountVoteLocal
        let delegatorsVotes: BigUInt
    }

    struct CastingVoting: Decodable {
        let referendumId: String
        let standardVote: SubqueryVotingResponse.StandardVote?
        let splitVote: SubqueryVotingResponse.SplitVote?
        let splitAbstainVote: SubqueryVotingResponse.SplitAbstainVote?
        let delegatorVotes: DelegatorVotesReponse?
    }

    struct DelegatorVotesReponse: Decodable {
        struct Delegation: Decodable {
            let delegator: AccountAddress
            let vote: SubqueryVotingResponse.RawVote
        }

        let nodes: [Delegation]
    }

    struct CastingVotings: Decodable {
        let nodes: [CastingVoting]
    }

    struct CastingResponse: Decodable {
        let castingVotings: CastingVotings
    }
}
