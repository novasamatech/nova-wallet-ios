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
                }
            }
        }
        """
    }
}

extension GovernanceTotalVotesFactory: GovernanceTotalVotesFactoryProtocol {
    func createOperation(referendumId: ReferendumIdLocal, votersType: ReferendumVotersType?) -> BaseOperation<ReferendumVotingAmount> {
        let query = if let votersType {
            prepareSplitAbstainVotesQuery(referendumId: referendumId)
        } else {
            prepareAllVotesQuery(referendumId: referendumId)
        }

        let operation = createOperation(
            for: query
        ) { (response: SubqueryVotingResponse.CastingResponse) -> ReferendumVotingAmount in
            response.castingVotings.nodes
                .compactMap { ReferendumVoterLocal(from: $0) }
                .reduce(
                    ReferendumVotingAmount(
                        aye: 0,
                        nay: 0,
                        abstain: 0
                    )
                ) { acc, voter in
                    ReferendumVotingAmount(
                        aye: acc.aye + voter.vote.ayes,
                        nay: acc.nay + voter.vote.nays,
                        abstain: acc.abstain + voter.vote.abstains
                    )
                }
        }

        return operation
    }
}
