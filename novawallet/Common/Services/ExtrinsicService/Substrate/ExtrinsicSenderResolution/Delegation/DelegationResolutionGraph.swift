import Foundation
import SubstrateSdk

enum DelegationError: Error {
    case noCompatibleProxyType
    case invalidMultisigParameters
    case noValidPath
    case emptyPaths
    case disjointPaths
}

struct DelegationKey: Hashable {
    let delegate: AccountId
    let delegated: AccountId
}

protocol AccountDelegationGraphValue {
    func pathDelegationValue() -> AccountDelegationPathValue?
    
    func toNestedValue(
        for callPath: CallCodingPath,
        at overallDepth: UInt
    ) -> AccountDelegationGraphValue?
}

protocol DelegationSource {
    func extractDelegationGraphValues(for chain: ChainModel) -> (DelegationKey, AccountDelegationGraphValue)?
}

extension DelegationResolution {
    struct GraphPath {
        struct PathComponent {
            let delegateId: AccountId
            let delegationValue: AccountDelegationGraphValue
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

        private let delegationValues: [DelegationKey: AccountDelegationGraphValue]
        private let delegatedToDelegates: [AccountId: Set<AccountId>]
        
        init(delegationValues: [DelegationKey: AccountDelegationGraphValue]) {
            self.delegationValues = delegationValues
            
            self.delegatedToDelegates = delegationValues.keys.reduce(into: [:]) { accum, key in
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
            from wallets: [DelegationSource],
            chain: ChainModel
        ) -> Graph {
            var delegationValues: [DelegationKey: AccountDelegationGraphValue] = wallets
                .compactMap { $0.extractDelegationGraphValues(for: chain) }
                .reduce(into: [:]) { $0[$1.0] = $1.1 }
            
            return Graph(delegationValues: delegationValues)
        }
    }
}

extension DelegationResolution.Graph {
    final class ProxyDelegationValue: AccountDelegationGraphValue {
        let proxyTypes: Set<Proxy.ProxyType>
        
        init(proxyTypes: Set<Proxy.ProxyType>) {
            self.proxyTypes = proxyTypes
        }
        
        func toNestedValue(
            for callPath: CallCodingPath,
            at overallDepth: UInt
        ) -> AccountDelegationGraphValue? {
            let possibleTypes: Set<Proxy.ProxyType> = if overallDepth == 0 {
                ProxyCallFilter.getProxyTypes(for: callPath)
            } else {
                [.any, .nonTransfer]
            }
            
            let availableTypes = proxyTypes.intersection(possibleTypes)
            
            return availableTypes.isEmpty ? nil : ProxyDelegationValue(proxyTypes: availableTypes)
        }
        
        func pathDelegationValue() -> AccountDelegationPathValue? {
            guard let proxyType = proxyTypes.first else { return nil }
            
            return DelegationResolution.PathFinder.ProxyDelegationValue(proxyType: proxyType)
        }
        
        func adding(type: Proxy.ProxyType) -> ProxyDelegationValue {
            .init(proxyTypes: proxyTypes.union([type]))
        }
    }
    
    final class MultisigDelegationValue: AccountDelegationGraphValue {
        let threshold: UInt16
        let signatories: [AccountId]
        
        init(
            threshold: UInt16,
            signatories: [AccountId]
        ) {
            self.threshold = threshold
            self.signatories = signatories
        }
        
        func toNestedValue(
            for callPath: CallCodingPath,
            at overallDepth: UInt
        ) -> AccountDelegationGraphValue? {
            self
        }
        
        func pathDelegationValue() -> AccountDelegationPathValue? {
            DelegationResolution.PathFinder.MultisigDelegationValue(
                threshold: threshold,
                signatories: signatories
            )
        }
    }
}

extension MetaAccountModel: DelegationSource {
    func extractDelegationGraphValues(for chain: ChainModel) -> (DelegationKey, AccountDelegationGraphValue)? {
        if
            type == .proxied,
            let proxiedChainAccount = proxyChainAccount(chainId: chain.chainId),
            let proxy = proxiedChainAccount.proxy {
            
            let key = DelegationKey(delegate: proxy.accountId, delegated: proxiedChainAccount.accountId)
            let value = DelegationResolution.Graph.ProxyDelegationValue(proxyTypes: [proxy.type])
            
            return (key, value)
        } else if
            type == .multisig,
            let multisig = multisigAccount()?.multisig {
            
            let allSignatories = multisig.otherSignatories + [multisig.signatory]
            
            let key = DelegationKey(delegate: multisig.signatory, delegated: multisig.accountId)
            let value = DelegationResolution.Graph.MultisigDelegationValue(
                threshold: UInt16(multisig.threshold),
                signatories: allSignatories
            )
            
            return (key, value)
        }
        
        return nil
    }
}
