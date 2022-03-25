import Foundation

protocol PhishingErrorPresentable {
    func presentPhishingWarning(
        address: AccountAddress?,
        view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )
}

extension PhishingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentPhishingWarning(
        address: AccountAddress?,
        view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable
            .walletSendPhishingWarningTitle(preferredLanguages: locale?.rLanguages)

        let message = R.string.localizable
            .walletSendPhishingWarningText(address ?? "", preferredLanguages: locale?.rLanguages)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentWarning(
        for title: String,
        message: String,
        action: @escaping () -> Void,
        view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let proceedTitle = R.string.localizable
            .commonProceed(preferredLanguages: locale?.rLanguages)
        let proceedAction = AlertPresentableAction(title: proceedTitle) {
            action()
        }

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [proceedAction],
            closeAction: closeTitle
        )

        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }
}
