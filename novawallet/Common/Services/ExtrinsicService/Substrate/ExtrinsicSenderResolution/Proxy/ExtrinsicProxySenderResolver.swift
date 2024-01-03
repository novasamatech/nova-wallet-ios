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

    private func buildAllAccounts() -> [AccountId: [MetaChainAccountResponse]] {
        wallets.reduce(into: [AccountId: [MetaChainAccountResponse]]()) { accum, wallet in
            guard let account = wallet.fetchMetaChainAccount(for: chain.accountRequest()) else {
                return
            }

            let accounts = accum[account.chainAccount.accountId] ?? []
            accum[account.chainAccount.accountId] = accounts + [account]
        }
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
            let paths = graph.resolveProxies(for: proxiedAccount.accountId, possibleProxyTypes: proxyTypes)

            do {
                try pathMerger.combine(callPath: callPath, paths: paths)
            } catch {
                resolutionFailures.append(.init(callPath: callPath, possibleTypes: proxyTypes, paths: paths))
            }
        }

        let allAccounts = buildAllAccounts()

        if
            let solution = try? ProxyResolution.PathFinder(accounts: allAccounts).find(from: pathMerger.availablePaths) {
            let newBuilders = try builders.map { builder in
                try builder.wrappingCalls { callJson in
                    let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context.toRawContext())
                    let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

                    guard let proxyPath = solution.callToPath[callPath] else {
                        return callJson
                    }

                    return try proxyPath.components.reduce(callJson) { call, component in
                        try Proxy.ProxyCall(
                            real: .accoundId(component.account.chainAccount.accountId),
                            forceProxyType: component.proxyType,
                            call: call
                        )
                        .runtimeCall()
                        .toScaleCompatibleJSON(with: context.toRawContext())
                    }
                }
            }

            let resolvedProxy = ExtrinsicSenderResolution.ResolvedProxy(
                proxyAccount: solution.proxy,
                proxiedAccount: proxiedAccount,
                paths: solution.callToPath,
                allAccounts: allAccounts,
                failures: resolutionFailures
            )

            return ExtrinsicSenderBuilderResolution(sender: .proxy(resolvedProxy), builders: newBuilders)
        } else {
            // if proxy resolution fails we still want to calculate fee and notify about failures

            let resolvedProxy = ExtrinsicSenderResolution.ResolvedProxy(
                proxyAccount: nil,
                proxiedAccount: proxiedAccount,
                paths: nil,
                allAccounts: allAccounts,
                failures: resolutionFailures
            )

            return ExtrinsicSenderBuilderResolution(sender: .proxy(resolvedProxy), builders: builders)
        }
    }
}

extension ExtrinsicProxySenderResolver {}
