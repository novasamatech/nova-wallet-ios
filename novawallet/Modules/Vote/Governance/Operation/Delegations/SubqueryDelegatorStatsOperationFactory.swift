import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class SubqueryDelegateStatsOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    private func prepareQuery(for activityStartBlock: BlockNumber) -> String {
        """
        {
           delegates {
              totalCount
              nodes {
                accountId
                delegators
                delegatorVotes
                delegateVotes(filter: {at: {greaterThanOrEqualTo: \(activityStartBlock)}}) {
                  totalCount
                }
              }
           }
        }
        """
    }
}

extension SubqueryDelegateStatsOperationFactory: GovernanceDelegateStatsFactoryProtocol {
    func fetchStatsWrapper(
        for activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<[GovernanceDelegateStats]> {
        let query = prepareQuery(for: activityStartBlock)

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

        let resultFactory = AnyNetworkResultFactory<[GovernanceDelegateStats]> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryDelegateStatsResponse>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response.delegates.nodes.map { node in
                    let delegatorVotes = BigUInt(node.delegatorVotes) ?? 0

                    return GovernanceDelegateStats(
                        address: node.accountId,
                        delegationsCount: node.delegators,
                        delegatedVotes: delegatorVotes,
                        recentVotes: node.delegateVotes.totalCount
                    )
                }
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
