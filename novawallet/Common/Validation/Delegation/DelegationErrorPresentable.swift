import Foundation

protocol DelegationErrorPresentable {
    func presentSelfDelegating(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )
}

extension DelegationErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentSelfDelegating(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.govAddDelegateSelfErrorTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.govAddDelegateSelfErrorMessage(
            preferredLanguages: locale?.rLanguages
        )

        let close = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: close, from: view)
    }
}
