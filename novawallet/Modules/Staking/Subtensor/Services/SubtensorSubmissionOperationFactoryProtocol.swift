import Foundation
import Operation_iOS

protocol SubtensorSubmissionOperationFactoryProtocol: AnyObject {
    func createFeeWrapper(
        for operation: SubtensorOperation
    ) -> CompoundOperationWrapper<ExtrinsicFeeProtocol>

    func createShieldQuoteWrapper(
        for operation: SubtensorOperation
    ) -> CompoundOperationWrapper<SubtensorShieldQuote?>

    func createSubmitWrapper(
        for operation: SubtensorOperation,
        shielded: Bool,
        signedClosure: @escaping () -> Void
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome>
}
