import Foundation
import SubstrateSdk

final class ProxyGraph {
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

    struct ResolutionPathComponent {
        let proxyAccountId: AccountId
        let applicableTypes: Set<Proxy.ProxyType>
    }

    struct ResolutionPath {
        let components: [ResolutionPathComponent]

        var accountIds: [AccountId] {
            components.map(\.proxyAccountId)
        }
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

        return ProxyGraph(graph: graph)
    }
}

final class ProxyPathMerger {
    enum MergerError: Error {
        case empthPaths(CallCodingPath)
        case disjointPaths(CallCodingPath)
    }

    private var availableProxies: Set<AccountId> = []
    private(set) var availablePaths: [CallCodingPath: [ProxyGraph.ResolutionPath]] = [:]

    func hasPaths(for call: CallCodingPath) -> Bool {
        availablePaths[call] != nil
    }

    func combine(callPath: CallCodingPath, paths: [ProxyGraph.ResolutionPath]) throws {
        let newProxies = Set(paths.compactMap(\.accountIds.last))

        guard !paths.isEmpty else {
            throw MergerError.empthPaths(callPath)
        }

        if !availableProxies.isEmpty {
            availableProxies = availableProxies.intersection(newProxies)
        } else {
            availableProxies = newProxies
        }

        guard !availableProxies.isEmpty else {
            throw MergerError.disjointPaths(callPath)
        }

        availablePaths[callPath] = paths

        availablePaths = availablePaths.mapValues { paths in
            paths.filter { path in
                if let proxy = path.components.last?.proxyAccountId, availableProxies.contains(proxy) {
                    return true
                } else {
                    return false
                }
            }
        }

        try availablePaths.forEach { keyValue in
            if keyValue.value.isEmpty {
                throw MergerError.disjointPaths(callPath)
            }
        }
    }
}

final class ProxyPathFinder {
    enum FinderError: Error {
        case noSolution
        case noAccount
    }

    struct PathComponent {
        let account: ChainAccountResponse
        let proxyType: Proxy.ProxyType
    }

    struct Path {
        let components: [PathComponent]
    }

    struct Result {
        let proxy: ChainAccountResponse
        let callToPath: [CallCodingPath: Path]
    }

    struct CallProxyKey: Hashable {
        let callPath: CallCodingPath
        let proxy: AccountId
    }

    let accounts: [AccountId: [ChainAccountResponse]]

    init(accounts: [AccountId: [ChainAccountResponse]]) {
        self.accounts = accounts
    }

    private func buildResult(
        from callPaths: [CallCodingPath: [ProxyGraph.ResolutionPath]],
        accounts: [AccountId: ChainAccountResponse]
    ) throws -> Result {
        let allCalls = Set(callPaths.keys)

        let callProxies = callPaths.reduce(into: [CallProxyKey: ProxyGraph.ResolutionPath]()) { accum, keyValue in
            let call = keyValue.key
            let paths = keyValue.value

            paths.forEach { path in
                guard let proxy = path.components.last?.proxyAccountId else {
                    return
                }

                let key = CallProxyKey(callPath: call, proxy: proxy)

                if let oldPath = accum[key], oldPath.components.count > path.components.count {
                    return
                }

                accum[key] = path
            }
        }

        guard
            let proxyAccountId = callProxies.keys.first?.proxy,
            let proxyAccount = accounts[proxyAccountId] else {
            throw FinderError.noAccount
        }

        let callToPath = try allCalls.reduce(into: [CallCodingPath: Path]()) { accum, call in
            let key = CallProxyKey(callPath: call, proxy: proxyAccountId)

            guard let solution = callProxies[key] else {
                throw FinderError.noSolution
            }

            let components = try solution.components.map { oldComponent in
                guard
                    let account = accounts[oldComponent.proxyAccountId],
                    let proxyType = oldComponent.applicableTypes.first else {
                    throw FinderError.noAccount
                }

                return PathComponent(account: account, proxyType: proxyType)
            }

            accum[call] = Path(components: components)
        }

        return Result(proxy: proxyAccount, callToPath: callToPath)
    }

    private func find(
        callPaths: [CallCodingPath: [ProxyGraph.ResolutionPath]],
        walletTypeFilter: (MetaAccountModelType) -> Bool
    ) -> Result? {
        do {
            let pathMerger = ProxyPathMerger()

            let accounts = accounts.reduce(into: [AccountId: ChainAccountResponse]()) { accum, keyValue in
                guard let account = keyValue.value.first(where: { walletTypeFilter($0.type) }) else {
                    return
                }

                accum[keyValue.key] = account
            }

            try callPaths.forEach { keyValue in
                let paths = keyValue.value.filter { path in
                    guard
                        let proxyAccountId = path.components.last?.proxyAccountId,
                        let account = accounts[proxyAccountId] else {
                        return false
                    }

                    return walletTypeFilter(account.type)
                }

                try pathMerger.combine(callPath: keyValue.key, paths: paths)
            }

            return try buildResult(from: pathMerger.availablePaths, accounts: accounts)
        } catch {
            return nil
        }
    }

    func find(from paths: [CallCodingPath: [ProxyGraph.ResolutionPath]]) throws -> Result {
        if let secretBasedResult = find(callPaths: paths, walletTypeFilter: { $0 == .secrets }) {
            return secretBasedResult
        } else if let notWatchOnlyResult = find(callPaths: paths, walletTypeFilter: { $0 != .watchOnly }) {
            return notWatchOnlyResult
        } else {
            let accounts = accounts.reduce(into: [AccountId: ChainAccountResponse]()) { accum, keyValue in
                guard let account = keyValue.value.first else {
                    return
                }

                accum[keyValue.key] = account
            }

            return try buildResult(from: paths, accounts: accounts)
        }
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

        let pathMerger = ProxyPathMerger()

        try allCalls.forEach { call in
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            guard pathMerger.hasPaths(for: callPath) else {
                return
            }

            let proxyTypes = ProxyCallFilter.getProxyTypes(for: callPath)
            let paths = graph.resolveProxies(for: proxiedAccount.accountId, possibleProxyTypes: proxyTypes)

            try pathMerger.combine(callPath: callPath, paths: paths)
        }

        let allAccounts = wallets.reduce(into: [AccountId: [ChainAccountResponse]]()) { accum, wallet in
            guard let account = wallet.fetch(for: chain.accountRequest()) else {
                return
            }

            let accounts = accum[account.accountId] ?? []
            accum[account.accountId] = accounts + [account]
        }

        let solution = try ProxyPathFinder(accounts: allAccounts).find(from: pathMerger.availablePaths)
        
        let newBuilders = try builders.map { builder in
            try builder.wrapCalls { callJson in
                let call = try $0.map(to: RuntimeCall<NoRuntimeArgs>.self)
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
                
                guard let proxyPath = solution.callToPath[callPath] else {
                    throw ProxyPathFinder.FinderError.noSolution
                }
                
                
            }
        }

        throw CommonError.dataCorruption
    }
}

extension ExtrinsicProxySenderResolver {}
