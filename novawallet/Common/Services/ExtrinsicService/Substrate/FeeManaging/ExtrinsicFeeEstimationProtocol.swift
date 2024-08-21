import Foundation
import Operation_iOS
import BigInt
import SubstrateSdk

protocol ExtrinsicFeeEstimationResultProtocol {
    var items: [ExtrinsicFeeProtocol] { get }
}

enum ExtrinsicFeeEstimatingError: Error {
    case brokenFee
}

protocol ExtrinsicFeeEstimating {
    func createFeeEstimatingWrapper(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>
}

protocol ExtrinsicFeeEstimationRegistring {
    func createFeeEstimatingWrapper(
        payingIn chainAssetId: ChainAssetId?,
        extrinsicCreatingResultClosure: @escaping () throws -> ExtrinsicsCreationResult
    ) -> CompoundOperationWrapper<ExtrinsicFeeEstimationResultProtocol>

    func createFeeInstallerWrapper(
        payingIn chainAssetId: ChainAssetId?,
        accountClosure: @escaping () throws -> ChainAccountResponse
    ) -> CompoundOperationWrapper<ExtrinsicFeeInstalling>
}
