import Foundation

extension MessageSheetPresentable where Self: ErrorPresentable {
    func presentNoSigningOrError(
        from view: ControllerBackedProtocol?,
        error: Error,
        locale: Locale?
    ) {
        if error.isWatchOnlySigning {
            presentDismissingNoSigningView(from: view)
        } else {
            _ = present(error: error, from: view, locale: locale)
        }
    }
}
