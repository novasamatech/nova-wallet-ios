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
     *  For proxy the implementation wraps with proxy.proxy original calls and
     *  then creates a batch of them. That is valid since all wrapped calls
     *  share the same set of proxy types and can be dispatched from the single origin
     *  provided by the batch call.
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

        let newBuilder = try builder.wrappingCalls { callJson in
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
        }.batchingCalls(with: coderFactory.metadata)

        let remainedComponents = Array(delegatedPath.components.dropFirst(1))

        return ReduceResult(
            updatedBuilder: newBuilder,
            remainedPathComponents: remainedComponents,
            lastCallOrigin: delegateAccountId
        )
    }
}
