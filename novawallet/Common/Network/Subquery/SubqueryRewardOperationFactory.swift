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
        let rewardsQuery = accountRewardsQuery(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            type: .reward
        )

        let slashQuery = accountRewardsQuery(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp,
            type: .slash
        )

        return """
        {
            rewards: \(rewardsQuery)
            slashes: \(slashQuery)
        }
        """
    }

    func accountRewardsQuery(
        address: AccountAddress,
        startTimestamp: Int64?,
        endTimestamp: Int64?,
        type: SubqueryRewardType
    ) -> String {
        var commonFilters: [SubqueryFilter] = [
            SubqueryEqualToFilter(fieldName: "address", value: address),
            SubqueryEqualToFilter(fieldName: "type", value: type)
        ]

        if let startTimestamp = startTimestamp {
            let filter = SubqueryGreaterThanOrEqualToFilter(fieldName: "timestamp", value: String(startTimestamp))
            commonFilters.append(filter)
        }

        if let endTimestamp = endTimestamp {
            let filter = SubqueryLessThanOrEqualToFilter(fieldName: "timestamp", value: String(endTimestamp))
            commonFilters.append(filter)
        }

        let queryFilter = SubqueryFilterBuilder.buildBlock(SubqueryCompoundFilter.and(commonFilters))

        return """
            accountRewards(
                         \(queryFilter)
                     ) {
                        groupedAggregates(groupBy: [ADDRESS]) {
                            sum {
                                amount
                            }
                        }
                     }
        """
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
            let response = try JSONDecoder().decode(SubqueryResponse<SubqueryTotalRewardsData>.self, from: data)

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                let rewardsString = response.rewards.groupedAggregates.first?.sum.amount
                let slashesString = response.slashes.groupedAggregates.first?.sum.amount

                let rewardsAmount: BigUInt = rewardsString.flatMap { BigUInt(scientific: $0) } ?? 0
                let slashesAmount: BigUInt = slashesString.flatMap { BigUInt(scientific: $0) } ?? 0

                return rewardsAmount > slashesAmount ? rewardsAmount - slashesAmount : 0
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
