import Foundation
import SubstrateSdk

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
    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        let graph = ProxyResolution.Graph.build(from: wallets, chain: chain)

        let context = codingFactory.createRuntimeJsonContext()

        let allCalls = try builders
            .flatMap { $0.getCalls() }
            .map { try $0.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context.toRawContext()) }

        let pathMerger = ProxyResolution.PathMerger()

        try allCalls.forEach { call in
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            guard pathMerger.hasPaths(for: callPath) else {
                return
            }

            let proxyTypes = ProxyCallFilter.getProxyTypes(for: callPath)
            let paths = graph.resolveProxies(for: proxiedAccount.accountId, possibleProxyTypes: proxyTypes)

            try pathMerger.combine(callPath: callPath, paths: paths)
        }

        let allAccounts = wallets.reduce(into: [AccountId: [MetaChainAccountResponse]]()) { accum, wallet in
            guard let account = wallet.fetchMetaChainAccount(for: chain.accountRequest()) else {
                return
            }

            let accounts = accum[account.chainAccount.accountId] ?? []
            accum[account.chainAccount.accountId] = accounts + [account]
        }

        let solution = try ProxyResolution.PathFinder(accounts: allAccounts).find(from: pathMerger.availablePaths)

        let newBuilders = try builders.map { builder in
            try builder.wrappingCalls { callJson in
                let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context.toRawContext())
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

                guard let proxyPath = solution.callToPath[callPath] else {
                    throw ProxyResolution.PathFinderError.noSolution
                }

                return try proxyPath.components.reduce(callJson) { call, component in
                    try Proxy.ProxyCall(
                        real: component.account.chainAccount.accountId,
                        forceProxyType: component.proxyType,
                        call: call
                    ).toScaleCompatibleJSON(with: context.toRawContext())
                }
            }
        }

        let resolvedProxy = ExtrinsicSenderResolution.ResolvedProxy(
            proxyAccount: solution.proxy,
            proxiedAccount: proxiedAccount,
            paths: solution.callToPath
        )

        return ExtrinsicSenderBuilderResolution(sender: .proxy(resolvedProxy), builders: newBuilders)
    }
}

extension ExtrinsicProxySenderResolver {}
