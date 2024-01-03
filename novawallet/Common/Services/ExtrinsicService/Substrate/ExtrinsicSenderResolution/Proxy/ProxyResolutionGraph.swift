import Foundation

extension ProxyResolution {
    struct ProxyProxiedKey: Hashable {
        let proxy: AccountId
        let proxied: AccountId
    }

    struct ProxyProxiedValue {
        let proxyTypes: Set<Proxy.ProxyType>

        func adding(type: Proxy.ProxyType) -> ProxyProxiedValue {
            .init(proxyTypes: proxyTypes.union([type]))
        }
    }

    struct GraphPath {
        struct PathComponent {
            let proxyAccountId: AccountId
            let applicableTypes: Set<Proxy.ProxyType>
        }

        let components: [PathComponent]

        var accountIds: [AccountId] {
            components.map(\.proxyAccountId)
        }
    }

    typealias GraphResult = [GraphPath]

    final class Graph {
        struct Context {
            let partialPath: [GraphPath.PathComponent]
            let visitedProxies: Set<AccountId>

            func isVisited(proxy: AccountId) -> Bool {
                visitedProxies.contains(proxy)
            }

            func adding(pathComponent: GraphPath.PathComponent) -> Graph.Context {
                .init(
                    partialPath: partialPath + [pathComponent],
                    visitedProxies: visitedProxies.union([pathComponent.proxyAccountId])
                )
            }
        }

        let proxiedToProxies: [AccountId: Set<AccountId>]
        let graphOfValues: [ProxyProxiedKey: ProxyProxiedValue]

        init(graph: [ProxyProxiedKey: ProxyProxiedValue]) {
            graphOfValues = graph
            proxiedToProxies = graph.keys.reduce(into: [AccountId: Set<AccountId>]()) { accum, key in
                let proxys = accum[key.proxied] ?? Set()
                accum[key.proxied] = proxys.union([key.proxy])
            }
        }

        private func derivePaths(from context: Graph.Context) -> GraphResult {
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

        private func resolveProxies(
            for proxiedAccountId: AccountId,
            possibleProxyTypes: Set<Proxy.ProxyType>,
            context: Graph.Context
        ) -> GraphResult {
            guard let proxies = proxiedToProxies[proxiedAccountId] else {
                return derivePaths(from: context)
            }

            let keys = proxies.map { ProxyProxiedKey(proxy: $0, proxied: proxiedAccountId) }

            return keys.flatMap { key in
                guard
                    let graphValue = graphOfValues[key],
                    !context.isVisited(proxy: key.proxy) else {
                    return derivePaths(from: context)
                }

                let applicableTypes = graphValue.proxyTypes.intersection(possibleProxyTypes)

                guard !applicableTypes.isEmpty else {
                    return derivePaths(from: context)
                }

                let component = GraphPath.PathComponent(proxyAccountId: key.proxy, applicableTypes: applicableTypes)
                let newContext = context.adding(pathComponent: component)

                // for nesting proxy we need either any or non transfer
                let nextPossibleTypes: Set<Proxy.ProxyType> = [.any, .nonTransfer]
                return resolveProxies(for: key.proxy, possibleProxyTypes: nextPossibleTypes, context: newContext)
            }
        }

        func resolveProxies(for proxiedAccountId: AccountId, possibleProxyTypes: Set<Proxy.ProxyType>) -> GraphResult {
            resolveProxies(
                for: proxiedAccountId,
                possibleProxyTypes: possibleProxyTypes,
                context: .init(partialPath: [], visitedProxies: [])
            )
        }

        static func build(from wallets: [MetaAccountModel], chain: ChainModel) -> Graph {
            let graph = wallets.reduce(into: [ProxyProxiedKey: ProxyProxiedValue]()) { accum, wallet in
                guard
                    wallet.type == .proxied,
                    let proxiedChainAccount = wallet.proxyChainAccount(chainId: chain.chainId),
                    let proxy = proxiedChainAccount.proxy else {
                    return
                }

                let key = ProxyProxiedKey(proxy: proxy.accountId, proxied: proxiedChainAccount.accountId)
                let value = accum[key] ?? ProxyProxiedValue(proxyTypes: [])
                accum[key] = value.adding(type: proxy.type)
            }

            return Graph(graph: graph)
        }
    }
}
