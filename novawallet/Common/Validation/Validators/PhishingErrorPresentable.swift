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
        let title = R.string(preferredLanguages: locale.rLanguages).localizable
            .walletSendPhishingWarningTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable
            .walletSendPhishingWarningText(address ?? "")

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
        let proceedTitle = R.string(preferredLanguages: locale.rLanguages).localizable
            .commonProceed()
        let proceedAction = AlertPresentableAction(title: proceedTitle) {
            action()
        }

        let closeTitle = R.string(preferredLanguages: locale.rLanguages).localizable
            .commonCancel()

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
