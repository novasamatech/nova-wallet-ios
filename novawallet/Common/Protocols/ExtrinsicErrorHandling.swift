import Foundation

protocol ExtrinsicErrorHandling {
    func handleExtrinsicErrorPresentation(
        _ error: Error,
        view: ControllerBackedProtocol?,
        completion: (Bool) -> Void
    )
}

extension ExtrinsicErrorHandling where Self: MessageSheetPresentable & ErrorPresentable {
    func handleExtrinsicErrorPresentation(
        _ error: Error,
        view: ControllerBackedProtocol?,
        completion _: (Bool) -> Void
    ) {
        if error.isWatchOnlySigning {
            presentPopingNoSigningView(from: view)
        } else if error.isHardwareWalletSigningCancelled {
            return
        }
    }
}
