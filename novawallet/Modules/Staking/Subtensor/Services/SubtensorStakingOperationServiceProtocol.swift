import Foundation
import Operation_iOS

protocol SubtensorStakingOperationServiceProtocol: AnyObject {
    func createFeeWrapper(
        for operation: SubtensorStakingOperation
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol>

    func createSubmitWrapper(
        for operation: SubtensorStakingOperation
    ) -> CompoundOperationWrapper<SubtensorStakingOperationOutcome>
}
