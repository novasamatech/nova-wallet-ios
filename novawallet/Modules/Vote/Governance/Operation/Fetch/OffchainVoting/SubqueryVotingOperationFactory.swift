import Foundation
import RobinHood
import SubstrateSdk

final class SubqueryVotingOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    private func prepareVotesQuery(for address: AccountAddress) -> String {
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
}

extension SubqueryVotingOperationFactory: GovernanceOffchainVotingFactoryProtocol {
    func createVotingFetchOperation(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainVoting> {
        let query = prepareVotesQuery(for: address)

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let body = JSON.dictionaryValue(["query": JSON.stringValue(query)])
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<GovernanceOffchainVoting> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryVotingResponse>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                let voting = response.castingVotings.nodes.reduce(
                    GovernanceOffchainVoting(address: address, votes: [:])
                ) { accum, castingVote in
                    accum.insertingSubquery(castingVote: castingVote)
                }

                return response.delegatorVotings.nodes.reduce(voting) { accum, delegatedVote in
                    accum.insertingSubquery(delegatedVote: delegatedVote)
                }
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
