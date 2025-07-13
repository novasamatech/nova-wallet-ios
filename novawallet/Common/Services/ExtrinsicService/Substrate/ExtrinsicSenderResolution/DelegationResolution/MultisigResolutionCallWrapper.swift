import Foundation
import SubstrateSdk

enum MultisigResolutionCallWrapperError: Error {
    case noSinglePath
}

class MultisigResolutionCallWrapper: DelegationResolutionCallWrapper {
    let delegatedAccount: ChainAccountResponse

    init(delegatedAccount: ChainAccountResponse) {
        self.delegatedAccount = delegatedAccount
    }

    /*
     *  The implementation just batches all the original
     *  calls that will be further wrapped with multisig.as_multi.
     *  This allows single operation creation instead of multiple ones.
     */
    override func reduceCallsIntoSingle(
        using solution: DelegationResolution.PathFinderResult,
        builder: ExtrinsicBuilderProtocol,
        coderFactory: RuntimeCoderFactoryProtocol
    ) throws -> ReduceResult {
        let context = coderFactory.createRuntimeJsonContext()

        guard let delegatedPath = solution.getFirstMatchingDelegatedPath(
            for: builder.getCalls(),
            context: context
        ) else {
            throw MultisigResolutionCallWrapperError.noSinglePath
        }

        let newBuilder = try builder.batchingCalls(with: coderFactory.metadata)

        return ReduceResult(
            updatedBuilder: newBuilder,
            remainedPathComponents: delegatedPath.components,
            lastCallOrigin: delegatedAccount.accountId
        )
    }
}
