import Foundation
import Operation_iOS

protocol SubtensorStakingSubmissionOperationFactoryProtocol: AnyObject {
    func createFeeWrapper(
        for operation: SubtensorStakingOperation
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol>

    func createSubmitWrapper(
        for operation: SubtensorStakingOperation,
        signedClosure: @escaping () -> Void
    ) -> CompoundOperationWrapper<SubtensorStakingOperationOutcome>
}
