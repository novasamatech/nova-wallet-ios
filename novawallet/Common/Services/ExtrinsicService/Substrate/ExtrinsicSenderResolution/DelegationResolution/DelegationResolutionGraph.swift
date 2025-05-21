import Foundation
import SubstrateSdk

extension DelegationResolution {
    struct GraphPath {
        struct PathComponent {
            let delegateId: AccountId
            let delegationValue: DelegationResolutionNodeProtocol
        }

        let components: [PathComponent]

        var accountIds: [AccountId] {
            components.map(\.delegateId)
        }
    }

    typealias GraphResult = [GraphPath]

    final class Graph {
        struct Context {
            let partialPath: [GraphPath.PathComponent]
            let visitedAccounts: Set<AccountId>

            func isVisited(_ account: AccountId) -> Bool {
                visitedAccounts.contains(account)
            }

            func adding(pathComponent: GraphPath.PathComponent) -> Context {
                .init(
                    partialPath: partialPath + [pathComponent],
                    visitedAccounts: visitedAccounts.union([pathComponent.delegateId])
                )
            }
        }

        private let delegationValues: [DelegationKey: DelegationResolutionNodeProtocol]
        private let delegatedToDelegates: [AccountId: Set<AccountId>]

        init(delegationValues: [DelegationKey: DelegationResolutionNodeProtocol]) {
            self.delegationValues = delegationValues

            delegatedToDelegates = delegationValues.keys.reduce(into: [:]) { accum, key in
                let delegateSet = accum[key.delegated] ?? Set()
                accum[key.delegated] = delegateSet.union([key.delegate])
            }
        }

        private func derivePaths(from context: Context) -> GraphResult {
            if !context.partialPath.isEmpty {
                // we found the max path but any subpath also applicable
                return (1 ... context.partialPath.count).map { pathLength in
                    let subPath = context.partialPath.prefix(pathLength)
                    return GraphPath(components: Array(subPath))
                }
            } else {
                return []
            }
        }

        private func findDelegationPaths(
            for delegatedAccountId: AccountId,
            callPath: CallCodingPath,
            context: Context,
            depth: UInt
        ) -> GraphResult {
            guard let delegates = delegatedToDelegates[delegatedAccountId] else {
                return derivePaths(from: context)
            }

            return delegates.flatMap { delegateId -> [GraphPath] in
                let key = DelegationKey(delegate: delegateId, delegated: delegatedAccountId)

                guard
                    let delegationValue = delegationValues[key],
                    !context.isVisited(delegateId)
                else {
                    return derivePaths(from: context)
                }

                guard let nestedValue = delegationValue.toNestedValue(
                    for: callPath,
                    at: depth
                ) else {
                    return derivePaths(from: context)
                }

                let component = DelegationResolution.GraphPath.PathComponent(
                    delegateId: delegateId,
                    delegationValue: nestedValue
                )

                let newContext = context.adding(pathComponent: component)

                return findDelegationPaths(
                    for: delegateId,
                    callPath: callPath,
                    context: newContext,
                    depth: depth + 1
                )
            }
        }

        func resolveDelegations(
            for delegatedAccountId: AccountId,
            callPath: CallCodingPath
        ) -> GraphResult {
            findDelegationPaths(
                for: delegatedAccountId,
                callPath: callPath,
                context: .init(partialPath: [], visitedAccounts: []),
                depth: 0
            )
        }

        static func build(
            from wallets: [DelegationResolutionNodeSourceProtocol],
            chain: ChainModel
        ) -> Graph {
            var delegationValues: [DelegationKey: DelegationResolutionNodeProtocol] = wallets
                .compactMap { $0.extractDelegationResolutionNode(for: chain) }
                .reduce(into: [:]) { $0[$1.0] = $1.1 }

            return Graph(delegationValues: delegationValues)
        }
    }
}
