import Foundation
import SubstrateSdk

enum ProxyResolutionCallWrapperError: Error {
    case noSinglePath
}

class ProxyResolutionCallWrapper: DelegationResolutionCallWrapper {
    let delegatedAccount: ChainAccountResponse
    let delegateAccountId: AccountId

    init(
        delegatedAccount: ChainAccountResponse,
        delegateAccountId: AccountId
    ) {
        self.delegatedAccount = delegatedAccount
        self.delegateAccountId = delegateAccountId
    }

    /*
     *  For proxy the implementation creates batch with original calls and then wraps it with proxy.proxy.
     *  The logic is the same for every platform.
     */
    override func reduceCallsIntoSingle(
        using solution: DelegationResolution.PathFinderResult,
        builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ReduceResult {
        let context = coderFactory.createRuntimeJsonContext()

        let allCalls = builder.getCalls()

        guard let delegatedPath = solution.getFirstMatchingDelegatedPath(
            for: allCalls,
            context: context
        ) else {
            throw ProxyResolutionCallWrapperError.noSinglePath
        }

        // fast path in case no batch

        guard allCalls.count > 1 else {
            return ReduceResult(
                updatedBuilder: builder,
                remainedPathComponents: delegatedPath.components,
                lastCallOrigin: delegatedAccount.accountId
            )
        }

        let newBuilder = try builder
            .batchingCalls(with: coderFactory.metadata)
            .wrappingCalls { callJson in
                let call = try callJson.map(to: RuntimeCall<NoRuntimeArgs>.self, with: context.toRawContext())
                let callPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

                guard
                    let delegatePath = solution.callToPath[callPath],
                    let component = delegatePath.components.first else {
                    return callJson
                }

                return try component.delegationValue.wrapCall(
                    callJson,
                    delegatedAccountId: delegatedAccount.accountId,
                    delegateAccountId: component.account.chainAccount.accountId,
                    context: context
                )
            }

        let remainedComponents = Array(delegatedPath.components.dropFirst(1))

        return ReduceResult(
            updatedBuilder: newBuilder,
            remainedPathComponents: remainedComponents,
            lastCallOrigin: delegateAccountId
        )
    }
}
