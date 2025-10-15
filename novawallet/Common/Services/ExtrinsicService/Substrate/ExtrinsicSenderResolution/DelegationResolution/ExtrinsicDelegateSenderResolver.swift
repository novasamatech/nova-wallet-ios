import Foundation
import SubstrateSdk

enum ExtrinsicDelegateSenderResolverError: Error {
    case unexpectedDelegationClass
}

final class ExtrinsicDelegateSenderResolver {
    let wallets: [MetaAccountModel]
    let delegatedAccount: ChainAccountResponse
    let delegateAccountId: AccountId
    let callWrapper: DelegationResolutionCallWrapperProtocol
    let chain: ChainModel

    init(
        delegatedAccount: ChainAccountResponse,
        delegateAccountId: AccountId,
        callWrapper: DelegationResolutionCallWrapperProtocol,
        wallets: [MetaAccountModel],
        chain: ChainModel
    ) {
        self.delegatedAccount = delegatedAccount
        self.delegateAccountId = delegateAccountId
        self.callWrapper = callWrapper
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
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        let results = try builders.map { builder in
            try callWrapper.wrapCalls(
                using: solution,
                builder: builder,
                coderFactory: coderFactory
            )
        }

        let paths = results.reduce(
            into: [JSON: DelegationResolution.PathFinderPath]()
        ) { accum, result in
            guard let callJson = result.builder.getCalls().first else {
                return
            }

            accum[callJson] = result.path
        }

        let builders = results.map(\.builder)

        let resolvedDelegate = ExtrinsicSenderResolution.ResolvedDelegate(
            delegateAccount: solution.delegate,
            delegatedAccount: delegatedAccount,
            paths: paths,
            allWallets: wallets,
            chain: chain,
            failures: resolutionFailures
        )

        return ExtrinsicSenderBuilderResolution(
            sender: .delegate(resolvedDelegate),
            builders: builders
        )
    }

    func ensureDelegationClass() throws -> DelegationClass {
        guard let delegationClass = delegatedAccount.type.delegationClass else {
            throw ExtrinsicDelegateSenderResolverError.unexpectedDelegationClass
        }

        return delegationClass
    }
}

extension ExtrinsicDelegateSenderResolver: ExtrinsicSenderResolving {
    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        let graph = DelegationResolution.Graph.build(from: wallets, chain: chain)

        let context = codingFactory.createRuntimeJsonContext()

        let delegationClass = try ensureDelegationClass()

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
                delegationClass: delegationClass,
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
                coderFactory: codingFactory
            )
        } else {
            // if delegate resolution fails we still want to calculate fee and notify about failures

            let resolvedDelegate = ExtrinsicSenderResolution.ResolvedDelegate(
                delegateAccount: nil,
                delegatedAccount: delegatedAccount,
                paths: [:],
                allWallets: wallets,
                chain: chain,
                failures: resolutionFailures
            )

            return ExtrinsicSenderBuilderResolution(sender: .delegate(resolvedDelegate), builders: builders)
        }
    }
}

extension ExtrinsicDelegateSenderResolver {}
