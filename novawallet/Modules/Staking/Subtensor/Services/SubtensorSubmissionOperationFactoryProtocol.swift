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
        blockTime: BlockTime,
        signedClosure: @escaping (SubtensorSubmissionRoute) -> Void
    ) -> CompoundOperationWrapper<SubtensorOperationOutcome>
}
