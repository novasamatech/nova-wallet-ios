import Foundation
import SubstrateSdk

final class ExtrinsicDelegateSenderResolver {
    let wallets: [MetaAccountModel]
    let delegatedAccount: ChainAccountResponse
    let delegateAccountId: AccountId
    let chain: ChainModel

    init(
        delegatedAccount: ChainAccountResponse,
        delegateAccountId: AccountId,
        wallets: [MetaAccountModel],
        chain: ChainModel
    ) {
        self.delegatedAccount = delegatedAccount
        self.delegateAccountId = delegateAccountId
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
        from solution: DelegationResolution.PathFinderResult,
        builders: [ExtrinsicBuilderProtocol],
        resolutionFailures: [ExtrinsicSenderResolution.ResolutionDelegateFailure],
        context: RuntimeJsonContext
    ) throws -> ExtrinsicSenderBuilderResolution {
        let newBuilders = try builders.map { builder in
            try builder.wrappingCalls { callJson in
                let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context.toRawContext())
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

                guard let delegatePath = solution.callToPath[callPath] else {
                    return callJson
                }

                let (resultCall, _) = try delegatePath.components.reduce(
                    (callJson, delegatedAccount.accountId)
                ) { callAndDelegatedAccount, component in
                    let call = callAndDelegatedAccount.0
                    let delegatedAccountId = callAndDelegatedAccount.1
                    let delegationKey = DelegationResolution.DelegationKey(
                        delegate: component.account.chainAccount.accountId,
                        delegated: delegatedAccountId
                    )

                    let newCall = try component.delegationValue.wrapCall(
                        call,
                        delegation: delegationKey,
                        context: context
                    )

                    return (newCall, component.account.chainAccount.accountId)
                }

                return resultCall
            }
        }

        // TODO: batch calls before wrapping into delegate
        let resolvedDelegate = ExtrinsicSenderResolution.ResolvedDelegate(
            delegateAccount: solution.delegate,
            delegatedAccount: delegatedAccount,
            path: Array(solution.callToPath.values)[0],
            allWallets: wallets,
            chain: chain,
            failures: resolutionFailures
        )

        return ExtrinsicSenderBuilderResolution(
            sender: .delegate(resolvedDelegate),
            builders: newBuilders
        )
    }
}

extension ExtrinsicDelegateSenderResolver: ExtrinsicSenderResolving {
    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        let graph = DelegationResolution.Graph.build(from: wallets, chain: chain)

        let context = codingFactory.createRuntimeJsonContext()

        let allCalls = try builders
            .flatMap { $0.getCalls() }
            .map { try $0.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context.toRawContext()) }

        let pathMerger = DelegationResolution.PathMerger()

        var resolutionFailures: [ExtrinsicSenderResolution.ResolutionDelegateFailure] = []

        allCalls.forEach { call in
            let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)
            guard !pathMerger.hasPaths(for: callPath) else {
                return
            }

            let paths = graph.resolveDelegations(
                for: delegatedAccount.accountId,
                callPath: callPath
            ).filter { path in
                path.components.first?.delegateId == delegateAccountId
            }

            do {
                try pathMerger.combine(callPath: callPath, paths: paths)
            } catch {
                resolutionFailures.append(.init(callPath: callPath, paths: paths))
            }
        }

        let allAccounts = buildAllAccounts()

        if
            let solution = try? DelegationResolution.PathFinder(
                accounts: allAccounts
            ).find(from: pathMerger.availablePaths) {
            return try createResult(
                from: solution,
                builders: builders,
                resolutionFailures: resolutionFailures,
                context: context
            )
        } else {
            // if delegate resolution fails we still want to calculate fee and notify about failures

            let resolvedDelegate = ExtrinsicSenderResolution.ResolvedDelegate(
                delegateAccount: nil,
                delegatedAccount: delegatedAccount,
                path: nil,
                allWallets: wallets,
                chain: chain,
                failures: resolutionFailures
            )

            return ExtrinsicSenderBuilderResolution(
                sender: .delegate(resolvedDelegate),
                builders: builders
            )
        }
    }
}

extension ExtrinsicDelegateSenderResolver {}
