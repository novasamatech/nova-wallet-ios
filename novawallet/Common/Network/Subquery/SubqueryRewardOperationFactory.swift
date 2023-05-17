import Foundation
import RobinHood
import SubstrateSdk
import BigInt

protocol SubqueryRewardOperationFactoryProtocol {
    func createOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryRewardOrSlashData>

    func createTotalRewardOperation(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<BigUInt>
}

extension SubqueryRewardOperationFactoryProtocol {
    func createOperation(address: String) -> BaseOperation<SubqueryRewardOrSlashData> {
        createOperation(address: address, startTimestamp: nil, endTimestamp: nil)
    }
}

final class SubqueryRewardOperationFactory {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    private func prepareQueryForAddress(
        _ address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            guard startTimestamp != nil || endTimestamp != nil else { return "" }
            var result = "timestamp:{"
            if let timestamp = startTimestamp {
                result.append("greaterThanOrEqualTo:\"\(timestamp)\",")
            }
            if let timestamp = endTimestamp {
                result.append("lessThanOrEqualTo:\"\(timestamp)\",")
            }
            result.append("}")
            return result
        }()

        return """
        {
            historyElements(
                 orderBy: TIMESTAMP_DESC,
                 filter: {
                     address: { equalTo: \"\(address)\"},
                     reward: { isNull: false },
                    \(timestampFilter)
                 }
             ) {
                nodes {
                    id
                    blockNumber
                    extrinsicIdx
                    extrinsicHash
                    timestamp
                    address
                    reward
                }
             }
        }
        """
    }

    private func prepareTotalRewardQuery(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        """
        query {
                    start: \(accountRewardsQuery(address: address, startTimestamp: startTimestamp, endTimestamp: endTimestamp, isAsc: true))
                    end: \(accountRewardsQuery(address: address, startTimestamp: startTimestamp, endTimestamp: endTimestamp, isAsc: false))
              }
        """
    }

    func accountRewardsQuery(
        address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        isAsc: Bool
    ) -> String {
        let filter = queryFilter(filters: [
            addressQueryFilter(address),
            timestampQueryFilter(startTimestamp: startTimestamp, endTimestamp: endTimestamp)
        ])
        let order = isAsc ? "BLOCK_NUMBER_ASC" : "BLOCK_NUMBER_DESC"
        return """
        accountRewards(
                         \(filter)
                         orderBy: \(order)
                         first: 1
                     ) {
                         nodes {
                             accumulatedAmount
                         }
                     }
        """
    }

    func queryFilter(filters: [String]) -> String {
        guard !filters.isEmpty else {
            return ""
        }
        let accumulatedFilters = filters.joined(separator: ",")

        return "filter: { \(filters.joined(separator: ",")) }"
    }

    func addressQueryFilter(_ address: AccountAddress) -> String {
        "address: { equalTo: \"\(address)\" }"
    }

    func timestampQueryFilter(startTimestamp: Int64?, endTimestamp: Int64?) -> String {
        let timestampFilter = [
            startTimestamp.map {
                "greaterThanOrEqualTo:\"\($0)\""
            },
            endTimestamp.map {
                "lessThanOrEqualTo:\"\($0)\""
            }
        ]
        .compactMap { $0 }
        .joined(separator: ",")

        return timestampFilter.isEmpty ? "" : "timestamp: { \(timestampFilter) }"
    }
}

extension SubqueryRewardOperationFactory: SubqueryRewardOperationFactoryProtocol {
    func createOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryRewardOrSlashData> {
        let queryString = prepareQueryForAddress(
            address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryRewardOrSlashData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryRewardOrSlashData>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func createTotalRewardOperation(
        for address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<BigUInt> {
        let queryString = prepareTotalRewardQuery(
            for: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: self.url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<BigUInt> { data in
            let response = try JSONDecoder().decode(SubqueryResponse<JSON>.self, from: data)

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                let startRewardString = response.start?
                    .nodes?.arrayValue?.first?.accumulatedAmount?.stringValue
                let endRewardString = response.end?
                    .nodes?.arrayValue?.first?.accumulatedAmount?.stringValue
                let startReward = startRewardString.map { BigUInt($0) ?? 0 }
                let endReward = endRewardString.map { BigUInt($0) ?? 0 }
                return endReward - startReward
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
