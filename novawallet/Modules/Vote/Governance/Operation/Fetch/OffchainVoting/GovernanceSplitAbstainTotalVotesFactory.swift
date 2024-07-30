import Foundation
import Operation_iOS
import BigInt

typealias ReferendumVotingAmount = BigUInt

protocol GovernanceSplitAbstainTotalVotesFactoryProtocol {
    func createOperation(referendumId: ReferendumIdLocal) -> BaseOperation<ReferendumVotingAmount>
}

final class GovernanceSplitAbstainTotalVotesFactory: SubqueryBaseOperationFactory {
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
}

extension GovernanceSplitAbstainTotalVotesFactory: GovernanceSplitAbstainTotalVotesFactoryProtocol {
    func createOperation(referendumId: ReferendumIdLocal) -> BaseOperation<ReferendumVotingAmount> {
        let query = prepareSplitAbstainVotesQuery(referendumId: referendumId)

        let operation = createOperation(
            for: query
        ) { (response: SubqueryVotingResponse.CastingResponse) -> BigUInt in
            response.castingVotings.nodes
                .compactMap { ReferendumVoterLocal(from: $0) }
                .reduce(into: 0) { $0 += $1.vote.abstains }
        }

        return operation
    }
}
