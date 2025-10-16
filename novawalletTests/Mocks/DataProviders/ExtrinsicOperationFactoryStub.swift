import Foundation
import Operation_iOS
import SubstrateSdk
@testable import novawallet

final class ExtrinsicOperationFactoryStub: ExtrinsicOperationFactoryProtocol {
    var connection: JSONRPCEngine { MockConnection() }

    func buildExtrinsic(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        payingFeeIn _: ChainAssetId?
    ) -> CompoundOperationWrapper<ExtrinsicBuiltModel> {
        let extrinsic = Data(repeating: 7, count: 32).toHex(includePrefix: true)

        let chainAccount = AccountGenerator.generateSubstrateChainAccountResponse(
            for: KnowChainId.westend
        )

        let builtModel = ExtrinsicBuiltModel(extrinsic: extrinsic, sender: .current(chainAccount))

        return CompoundOperationWrapper.createWithResult(builtModel)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        indexes: IndexSet,
        payingIn _: ChainAssetId?
    ) -> CompoundOperationWrapper<SubmitIndexedExtrinsicResult> {
        let results = indexes.map { index in
            let txHash = Data(repeating: UInt8(index), count: 32).toHex(includePrefix: true)

            let chainAccount = AccountGenerator.generateSubstrateChainAccountResponse(
                for: KnowChainId.westend
            )

            let submittedModel = ExtrinsicSubmittedModel(
                txHash: txHash,
                sender: .current(chainAccount)
            )

            return SubmitIndexedExtrinsicResult.IndexedResult(
                index: index,
                result: .success(submittedModel)
            )
        }

        let submitResult = SubmitIndexedExtrinsicResult(builderClosure: closure, results: results)

        return CompoundOperationWrapper.createWithResult(submitResult)
    }

    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        indexes: IndexSet,
        payingIn _: ChainAssetId?
    ) -> CompoundOperationWrapper<FeeIndexedExtrinsicResult> {
        let fee = ExtrinsicFee(amount: 10_000_000_000, payer: nil, weight: .init(refTime: 10_005_000, proofSize: 0))

        let results = indexes.map { index in
            FeeIndexedExtrinsicResult.IndexedResult(
                index: index,
                result: .success(fee)
            )
        }

        let feeResult = FeeIndexedExtrinsicResult(
            builderClosure: closure,
            results: results
        )

        return CompoundOperationWrapper.createWithResult(feeResult)
    }
}
