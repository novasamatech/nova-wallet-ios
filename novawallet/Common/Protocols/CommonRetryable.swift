import Foundation

protocol CommonRetryable {
    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        cancelAction: String,
        locale: Locale?,
        retryAction: @escaping () -> Void
    )

    func presentTryAgainOperation(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        actionTitle: String,
        retryAction: @escaping () -> Void
    )
}

extension CommonRetryable where Self: AlertPresentable {
    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        locale: Locale?,
        retryAction: @escaping () -> Void
    ) {
        presentRequestStatus(
            on: view,
            title: title,
            message: message,
            cancelAction: R.string.localizable.commonSkip(preferredLanguages: locale?.rLanguages),
            locale: locale,
            retryAction: retryAction
        )
    }

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
            cancelAction: R.string.localizable.commonSkip(preferredLanguages: locale?.rLanguages),
            locale: locale,
            retryAction: retryAction
        )
    }

    // swiftlint:disable:next function_parameter_count
    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        cancelAction: String,
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
            closeAction: cancelAction
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentTryAgainOperation(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        actionTitle: String,
        retryAction: @escaping () -> Void
    ) {
        let retryViewModel = AlertPresentableAction(
            title: actionTitle,
            handler: retryAction
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [retryViewModel],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
