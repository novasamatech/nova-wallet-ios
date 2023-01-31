import Foundation
import RobinHood
import SubstrateSdk

final class SubqueryVotingOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

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

    private func createRequestFactory(for query: String, url: URL) -> BlockNetworkRequestFactory {
        BlockNetworkRequestFactory {
            var request = URLRequest(url: url)

            let body = JSON.dictionaryValue(["query": JSON.stringValue(query)])
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }
    }
}

extension SubqueryVotingOperationFactory: GovernanceOffchainVotingFactoryProtocol {
    func createAllVotesFetchOperation(
        for address: AccountAddress
    ) -> CompoundOperationWrapper<GovernanceOffchainVoting> {
        let query = prepareCastingAndDelegatorVotesQuery(for: address)

        let requestFactory = createRequestFactory(for: query, url: url)

        let resultFactory = AnyNetworkResultFactory<GovernanceOffchainVoting> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryVotingResponse.CastingAndDelegatorResponse>.self,
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

    func createDirectVotesFetchOperation(
        for address: AccountAddress,
        from block: BlockNumber?
    ) -> CompoundOperationWrapper<GovernanceOffchainVotes> {
        let query = prepareVotingActivityQuery(for: address, from: block)

        let requestFactory = createRequestFactory(for: query, url: url)

        let resultFactory = AnyNetworkResultFactory<GovernanceOffchainVotes> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryVotingResponse.CastingResponse>.self,
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

                return voting.getAllDirectVotes()
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
