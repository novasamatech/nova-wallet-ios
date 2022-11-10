@testable import novawallet
import RobinHood
import SubstrateSdk

final class ExtrinsicOperationFactoryStub: ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { MockJSONRPCEngine() }

    func buildExtrinsic(_ closure: @escaping ExtrinsicBuilderClosure, signer: SigningWrapperProtocol) -> CompoundOperationWrapper<String> {
        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)

        return CompoundOperationWrapper.createWithResult(txHash)
    }

    func submit(_ closure: @escaping ExtrinsicBuilderIndexedClosure, signer: SigningWrapperProtocol, numberOfExtrinsics: Int) -> CompoundOperationWrapper<[SubmitExtrinsicResult]> {
        let txHash = Data(repeating: 7, count: 32).toHex(includePrefix: true)

        return CompoundOperationWrapper.createWithResult([.success(txHash)])
    }

    func estimateFeeOperation(_ closure: @escaping ExtrinsicBuilderIndexedClosure, numberOfExtrinsics: Int) -> CompoundOperationWrapper<[FeeExtrinsicResult]> {
        let dispatchInfo = RuntimeDispatchInfo(
            fee: "10000000000",
            weight: 10005000
        )

        return CompoundOperationWrapper.createWithResult([.success(dispatchInfo)])
    }
}
