import Foundation
import RobinHood
import SubstrateSdk
import BigInt

final class SubqueryDelegateStatsOperationFactory: SubqueryBaseOperationFactory {
    private func prepareListQuery(for activityStartBlock: BlockNumber) -> String {
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

    private func prepareListByIdsQuery(
        from addresses: String,
        activityStartBlock: BlockNumber
    ) -> String {
        """
        {
           delegates(filter: {accountId: {in: [\(addresses)]}}) {
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

    private func prepareDetailsQuery(
        for delegate: AccountAddress,
        activityStartBlock: BlockNumber
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
                    recentVotes: delegateVotes(filter: {at: {greaterThanOrEqualTo: \(activityStartBlock)}}) {
                        totalCount
                    }
                }
            }
        }
        """
    }

    private func internalFetchStatsWrapper(from query: String) -> CompoundOperationWrapper<[GovernanceDelegateStats]> {
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
}

extension SubqueryDelegateStatsOperationFactory: GovernanceDelegateStatsFactoryProtocol {
    func fetchStatsWrapper(
        for activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<[GovernanceDelegateStats]> {
        let query = prepareListQuery(for: activityStartBlock)
        return internalFetchStatsWrapper(from: query)
    }

    func fetchStatsByIdsWrapper(
        from delegateIds: Set<AccountAddress>,
        activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<[GovernanceDelegateStats]> {
        let addresses = String(delegateIds.map { "\"\($0)\"" }.joined(separator: ","))
        let query = prepareListByIdsQuery(from: addresses, activityStartBlock: activityStartBlock)

        return internalFetchStatsWrapper(from: query)
    }

    func fetchDetailsWrapper(
        for delegate: AccountAddress,
        activityStartBlock: BlockNumber
    ) -> CompoundOperationWrapper<GovernanceDelegateDetails?> {
        let query = prepareDetailsQuery(for: delegate, activityStartBlock: activityStartBlock)

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
