import Foundation
import SubstrateSdk

final class ProxyGraph {
    struct ProxyProxiedKey: Hashable {
        let proxy: AccountId
        let proxied: AccountId
    }

    struct ProxyProxiedValue {
        let proxyWallets: [MetaAccountModel]
        let proxyTypes: Set<Proxy.ProxyType>

        func adding(type: Proxy.ProxyType) -> ProxyProxiedValue {
            .init(proxyWallets: proxyWallets, proxyTypes: proxyTypes.union([type]))
        }

        func adding(proxyWallet: MetaAccountModel) -> ProxyProxiedValue {
            .init(proxyWallets: proxyWallets + [proxyWallet], proxyTypes: proxyTypes)
        }
    }

    struct ResolutionPathComponent {
        let proxyAccountId: AccountId
        let applicableTypes: Set<Proxy.ProxyType>
    }

    struct ResolutionPath {
        let components: [ResolutionPathComponent]
    }

    struct ResolutionContext {
        let partialPath: [ResolutionPathComponent]
        let visitedProxies: Set<AccountId>

        func isVisited(proxy: AccountId) -> Bool {
            visitedProxies.contains(proxy)
        }

        func adding(pathComponent: ResolutionPathComponent) -> ResolutionContext {
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

    private func derivePaths(from context: ResolutionContext) -> [ResolutionPath] {
        if !context.partialPath.isEmpty {
            let path = ResolutionPath(components: context.partialPath)
            return [path]
        } else {
            return []
        }
    }

    private func resolveProxies(
        for proxiedAccountId: AccountId,
        possibleProxyTypes: Set<Proxy.ProxyType>,
        context: ResolutionContext
    ) -> [ResolutionPath] {
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

            let component = ResolutionPathComponent(proxyAccountId: key.proxy, applicableTypes: applicableTypes)
            let newContext = context.adding(pathComponent: component)

            // for nesting proxy we need either any or non transfer
            let nextPossibleTypes: Set<Proxy.ProxyType> = [.any, .nonTransfer]
            return resolveProxies(for: key.proxy, possibleProxyTypes: nextPossibleTypes, context: newContext)
        }
    }

    func resolveProxies(for proxiedAccountId: AccountId, possibleProxyTypes: Set<Proxy.ProxyType>) -> [ResolutionPath] {
        resolveProxies(
            for: proxiedAccountId,
            possibleProxyTypes: possibleProxyTypes,
            context: .init(partialPath: [], visitedProxies: [])
        )
    }

    static func build(from wallets: [MetaAccountModel], chain: ChainModel) -> ProxyGraph {
        var graph = wallets.reduce(into: [ProxyProxiedKey: ProxyProxiedValue]()) { accum, wallet in
            guard
                wallet.type == .proxied,
                let proxiedChainAccount = wallet.proxyChainAccount(chainId: chain.chainId),
                let proxy = proxiedChainAccount.proxy else {
                return
            }

            let key = ProxyProxiedKey(proxy: proxy.accountId, proxied: proxiedChainAccount.accountId)
            let value = accum[key] ?? ProxyProxiedValue(proxyWallets: [], proxyTypes: [])
            accum[key] = value.adding(type: proxy.type)
        }

        graph = wallets.reduce(into: graph) { accum, wallet in
            guard let proxyAccountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
                return
            }

            let keys = accum.keys.filter { $0.proxy == proxyAccountId }

            for key in keys {
                accum[key] = accum[key]?.adding(proxyWallet: wallet)
            }
        }

        return ProxyGraph(graph: graph)
    }
}

final class ExtrinsicProxySenderResolver {
    let wallets: [MetaAccountModel]
    let proxiedAccount: ChainAccountResponse
    let chain: ChainModel

    init(proxiedAccount: ChainAccountResponse, wallets: [MetaAccountModel], chain: ChainModel) {
        self.proxiedAccount = proxiedAccount
        self.wallets = wallets
        self.chain = chain
    }
}

extension ExtrinsicProxySenderResolver: ExtrinsicSenderResolving {
    func resolveSender(wrapping builders: [ExtrinsicBuilderProtocol]) throws -> ExtrinsicSenderBuilderResolution {
        let graph = ProxyGraph.build(from: wallets, chain: chain)

        let allCalls = try builders
            .flatMap { $0.getCalls() }
            .map { try $0.map(to: RuntimeCall<NoRuntimeArgs>.self) }

        for call in allCalls {
            let proxyTypes = ProxyCallFilter.getProxyTypes(for: .init(moduleName: call.moduleName, callName: call.callName))
            let paths = graph.resolveProxies(for: proxiedAccount.accountId, possibleProxyTypes: proxyTypes)
        }

        throw CommonError.dataCorruption
    }
}

extension ExtrinsicProxySenderResolver {}
