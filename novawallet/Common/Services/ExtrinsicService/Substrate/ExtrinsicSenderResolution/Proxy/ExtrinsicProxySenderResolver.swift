import Foundation
import SubstrateSdk

final class ExtrinsicProxySenderResolver {
    let wallets: [MetaAccountModel]
    let proxiedAccount: ChainAccountResponse
    let proxyAccountId: AccountId
    let chain: ChainModel

    init(
        proxiedAccount: ChainAccountResponse,
        proxyAccountId: AccountId,
        wallets: [MetaAccountModel],
        chain: ChainModel
    ) {
        self.proxiedAccount = proxiedAccount
        self.proxyAccountId = proxyAccountId
        self.wallets = wallets
        self.chain = chain
    }

    private func buildAllAccounts() -> [AccountId: [MetaChainAccountResponse]] {
        wallets.reduce(into: [AccountId: [MetaChainAccountResponse]]()) { accum, wallet in
            guard let account = wallet.fetchMetaChainAccount(for: chain.accountRequest()) else {
                return
            }

            let accounts = accum[account.chainAccount.accountId] ?? []
            accum[account.chainAccount.accountId] = accounts + [account]
        }
    }

    private func createResult(
        from solution: ProxyResolution.PathFinderResult,
        builders: [ExtrinsicBuilderProtocol],
        resolutionFailures: [ExtrinsicSenderResolution.ResolutionProxyFailure],
        context: RuntimeJsonContext
    ) throws -> ExtrinsicSenderBuilderResolution {
        let newBuilders = try builders.map { builder in
            try builder.wrappingCalls { callJson in
                let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context.toRawContext())
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

                guard let proxyPath = solution.callToPath[callPath] else {
                    return callJson
                }

                let (resultCall, _) = try proxyPath.components.reduce(
                    (callJson, proxiedAccount.accountId)
                ) { callAndProxied, component in
                    let call = callAndProxied.0
                    let proxiedAccountId = callAndProxied.1

                    let newCall = try Proxy.ProxyCall(
                        real: .accoundId(proxiedAccountId),
                        forceProxyType: component.proxyType,
                        call: call
                    )
                    .runtimeCall()
                    .toScaleCompatibleJSON(with: context.toRawContext())

                    return (newCall, component.account.chainAccount.accountId)
                }

                return resultCall
            }
        }

        let resolvedProxy = ExtrinsicSenderResolution.ResolvedProxy(
            proxyAccount: solution.proxy,
            proxiedAccount: proxiedAccount,
            paths: solution.callToPath,
            allWallets: wallets,
            chain: chain,
            failures: resolutionFailures
        )

        return ExtrinsicSenderBuilderResolution(sender: .proxy(resolvedProxy), builders: newBuilders)
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

        var resolutionFailures: [ExtrinsicSenderResolution.ResolutionProxyFailure] = []

        allCalls.forEach { call in
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            guard !pathMerger.hasPaths(for: callPath) else {
                return
            }

            let proxyTypes = ProxyCallFilter.getProxyTypes(for: callPath)
            let paths = graph.resolveProxies(
                for: proxiedAccount.accountId,
                possibleProxyTypes: proxyTypes
            ).filter { path in
                path.components.first?.proxyAccountId == proxyAccountId
            }

            do {
                try pathMerger.combine(callPath: callPath, paths: paths)
            } catch {
                resolutionFailures.append(.init(callPath: callPath, possibleTypes: proxyTypes, paths: paths))
            }
        }

        let allAccounts = buildAllAccounts()

        if
            let solution = try? ProxyResolution.PathFinder(
                accounts: allAccounts
            ).find(from: pathMerger.availablePaths) {
            return try createResult(
                from: solution,
                builders: builders,
                resolutionFailures: resolutionFailures,
                context: context
            )
        } else {
            // if proxy resolution fails we still want to calculate fee and notify about failures

            let resolvedProxy = ExtrinsicSenderResolution.ResolvedProxy(
                proxyAccount: nil,
                proxiedAccount: proxiedAccount,
                paths: nil,
                allWallets: wallets,
                chain: chain,
                failures: resolutionFailures
            )

            return ExtrinsicSenderBuilderResolution(sender: .proxy(resolvedProxy), builders: builders)
        }
    }
}

extension ExtrinsicProxySenderResolver {}
