import Foundation
import SubstrateSdk

struct DelegationResolutionCallWrapperResult {
    let builder: ExtrinsicBuilderProtocol
    let path: DelegationResolution.PathFinderPath
}

protocol DelegationResolutionCallWrapperProtocol {
    func wrapCalls(
        using solution: DelegationResolution.PathFinderResult,
        builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> DelegationResolutionCallWrapperResult
}

class DelegationResolutionCallWrapper {
    struct ReduceResult {
        let updatedBuilder: ExtrinsicBuilderProtocol
        let remainedPathComponents: [DelegationResolution.PathFinderPath.Component]
        let lastCallOrigin: AccountId
    }

    func reduceCallsIntoSingle(
        using _: DelegationResolution.PathFinderResult,
        builder _: ExtrinsicBuilderProtocol,
        coderFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ReduceResult {
        fatalError("Subsclass must provide implementation")
    }
}

extension DelegationResolutionCallWrapper: DelegationResolutionCallWrapperProtocol {
    func wrapCalls(
        using solution: DelegationResolution.PathFinderResult,
        builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> DelegationResolutionCallWrapperResult {
        let reducerResult = try reduceCallsIntoSingle(
            using: solution,
            builder: builder,
            coderFactory: coderFactory
        )

        guard !reducerResult.remainedPathComponents.isEmpty else {
            return DelegationResolutionCallWrapperResult(
                builder: reducerResult.updatedBuilder,
                path: .init(components: reducerResult.remainedPathComponents)
            )
        }

        let context = coderFactory.createRuntimeJsonContext()

        let newBuilder = try reducerResult.updatedBuilder.wrappingCalls { callJson in
            let (resultCall, _) = try reducerResult.remainedPathComponents.reduce(
                (callJson, reducerResult.lastCallOrigin)
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

        return DelegationResolutionCallWrapperResult(
            builder: newBuilder,
            path: .init(components: reducerResult.remainedPathComponents)
        )
    }
}
