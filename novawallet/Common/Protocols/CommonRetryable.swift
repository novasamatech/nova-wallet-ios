import Foundation

protocol CommonRetryable {
    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        locale: Locale?,
        retryAction: @escaping () -> Void
    )
}

extension CommonRetryable where Self: AlertPresentable {
    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        locale: Locale?,
        retryAction: @escaping () -> Void
    ) {
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.commonRequestRetry(preferredLanguages: locale?.rLanguages)

        presentRequestStatus(
            on: view,
            title: title,
            message: message,
            locale: locale,
            retryAction: retryAction
        )
    }

    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        locale: Locale?,
        retryAction: @escaping () -> Void
    ) {
        let retryViewModel = AlertPresentableAction(
            title: R.string.localizable.commonRetry(preferredLanguages: locale?.rLanguages),
            handler: retryAction
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [retryViewModel],
            closeAction: R.string.localizable.commonSkip(preferredLanguages: locale?.rLanguages)
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
