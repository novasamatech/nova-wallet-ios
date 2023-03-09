@testable import novawallet
import RobinHood
import SubstrateSdk

final class ExtrinsicOperationFactoryStub: ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { MockJSONRPCEngine() }

    func buildExtrinsic(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol) -> CompoundOperationWrapper<String> {
        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)

        return CompoundOperationWrapper.createWithResult(txHash)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        let results = indexes.map { index in
            let txHash = Data(repeating: UInt8(index), count: 32).toHex(includePrefix: true)

            return SubmitIndexedExtrinsicResult.IndexedResult(
                index: index,
                result: .success(txHash)
            )
        }

        let submitResult = SubmitIndexedExtrinsicResult(builderClosure: closure, results: results)

        return CompoundOperationWrapper.createWithResult(submitResult)
    }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: IndexSet
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        let dispatchInfo = RuntimeDispatchInfo(
            fee: "10000000000",
            weight: 10005000
        )

        let results = indexes.map { index in
            FeeIndexedExtrinsicResult.IndexedResult(
                index: index,
                result: .success(dispatchInfo)
            )
        }

        let feeResult = FeeIndexedExtrinsicResult(
            builderClosure: closure,
            results: results
        )

        return CompoundOperationWrapper.createWithResult(feeResult)
    }
}
