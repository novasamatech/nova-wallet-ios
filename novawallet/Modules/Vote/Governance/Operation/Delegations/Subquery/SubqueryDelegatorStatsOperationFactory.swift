import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class SubqueryDelegateStatsOperationFactory: SubqueryBaseOperationFactory {}

// MARK: - Private

private extension SubqueryDelegateStatsOperationFactory {
    func prepareListQuery(for threshold: TimepointThreshold) -> String {
        """
        {
           delegates {
              totalCount
              nodes {
                accountId
                delegators
                delegatorVotes
                delegateVotes(filter: \(createFilter(for: threshold))) {
                  totalCount
                }
              }
           }
        }
        """
    }

    func prepareListByIdsQuery(
        from addresses: String,
        threshold: TimepointThreshold
    ) -> String {
        """
        {
           delegates(filter: {accountId: {in: [\(addresses)]}}) {
              totalCount
              nodes {
                accountId
                delegators
                delegatorVotes
                delegateVotes(filter: \(createFilter(for: threshold))) {
                  totalCount
                }
              }
           }
        }
        """
    }

    func prepareDetailsQuery(
        for delegate: AccountAddress,
        threshold: TimepointThreshold
    ) -> String {
        """
        {
            delegates(filter: {accountId: {equalTo: "\(delegate)"}}) {
                nodes {
                    accountId
                    delegators
                    delegatorVotes
                    allVotes: delegateVotes {
                        totalCount
                    }
                    recentVotes: delegateVotes(filter: \(createFilter(for: threshold))) {
                        totalCount
                    }
                }
            }
        }
        """
    }

    func internalFetchStatsWrapper(from query: String) -> CompoundOperationWrapper<[GovernanceDelegateStats]> {
        let operation = createOperation(
            for: query
        ) { (response: SubqueryDelegateStatsResponse) -> [GovernanceDelegateStats] in
            response.delegates.nodes.map { node in
                let delegatorVotes = BigUInt(node.delegatorVotes) ?? 0

                return GovernanceDelegateStats(
                    address: node.accountId,
                    delegationsCount: node.delegators,
                    delegatedVotes: delegatorVotes,
                    recentVotes: node.delegateVotes.totalCount
                )
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    func createFilter(for threshold: TimepointThreshold) -> String {
        switch threshold {
        case let .blockNumber(blockNumber):
            "{at: {greaterThanOrEqualTo: \(blockNumber)}}"
        case let .timestamp(timestamp):
            "{timestamp: {greaterThanOrEqualTo: \(timestamp)}}"
        }
    }
}

// MARK: - GovernanceDelegateStatsFactoryProtocol

extension SubqueryDelegateStatsOperationFactory: GovernanceDelegateStatsFactoryProtocol {
    func fetchStatsWrapper(
        for threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<[GovernanceDelegateStats]> {
        let query = prepareListQuery(for: threshold)
        return internalFetchStatsWrapper(from: query)
    }

    func fetchStatsByIdsWrapper(
        from delegateIds: Set<AccountAddress>,
        threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<[GovernanceDelegateStats]> {
        let addresses = String(delegateIds.map { "\"\($0)\"" }.joined(separator: ","))
        let query = prepareListByIdsQuery(from: addresses, threshold: threshold)

        return internalFetchStatsWrapper(from: query)
    }

    func fetchDetailsWrapper(
        for delegate: AccountAddress,
        threshold: TimepointThreshold
    ) -> CompoundOperationWrapper<GovernanceDelegateDetails?> {
        let query = prepareDetailsQuery(for: delegate, threshold: threshold)

        let operation = createOperation(
            for: query
        ) { (response: SubqueryDelegateDetailsResponse) -> GovernanceDelegateDetails? in
            response.delegates.nodes.first.map { node in
                let delegatorVotes = BigUInt(node.delegatorVotes) ?? 0

                let stats = GovernanceDelegateStats(
                    address: node.accountId,
                    delegationsCount: node.delegators,
                    delegatedVotes: delegatorVotes,
                    recentVotes: node.recentVotes.totalCount
                )

                return .init(stats: stats, allVotes: node.allVotes.totalCount)
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
