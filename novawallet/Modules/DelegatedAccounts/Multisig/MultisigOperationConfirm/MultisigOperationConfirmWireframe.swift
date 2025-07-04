import Foundation

final class MultisigOperationConfirmWireframe: MultisigOperationConfirmWireframeProtocol {
    func showAddCallData(from _: ControllerBackedProtocol?) {
        // TODO: Implement add call data screen
    }

    func showSubmisstionresult(
        for submissionType: MultisigSubmissionType,
        locale: Locale,
        from _: ControllerBackedProtocol?
    ) {
        let text = switch submissionType {
        case .approve:
            R.string.localizable.commonTransactionSigned(preferredLanguages: locale.rLanguages)
        case .reject:
            R.string.localizable.commonTransactionRejected(preferredLanguages: locale.rLanguages)
        }
    }
}
