import Foundation

protocol CommonRetryable {
    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        with viewModel: RequestStatusAlertModel
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
        with viewModel: RequestStatusAlertModel
    ) {
        var actions: [AlertPresentableAction] = [
            AlertPresentableAction(
                title: R.string.localizable.commonRetry(
                    preferredLanguages: viewModel.locale?.rLanguages
                ),
                handler: viewModel.retryAction
            )
        ]

        if let skipAction = viewModel.skipAction {
            let skipViewModel = AlertPresentableAction(
                title: R.string.localizable.commonSkip(
                    preferredLanguages: viewModel.locale?.rLanguages
                ),
                handler: skipAction
            )

            actions.insert(skipViewModel, at: 0)
        }

        let viewModel = AlertPresentableViewModel(
            title: viewModel.title,
            message: viewModel.message,
            actions: actions,
            closeAction: viewModel.cancelAction
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        locale: Locale?,
        retryAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    ) {
        presentRequestStatus(
            on: view,
            with: .init(
                title: title,
                message: message,
                locale: locale,
                retryAction: retryAction,
                skipAction: skipAction
            )
        )
    }

    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        title: String,
        message: String,
        cancelAction: String? = nil,
        locale: Locale?,
        retryAction: @escaping () -> Void
    ) {
        let cancelActionTitle = cancelAction ?? R.string.localizable.commonSkip(
            preferredLanguages: locale?.rLanguages
        )

        presentRequestStatus(
            on: view,
            with: .init(
                title: title,
                message: message,
                cancelAction: cancelActionTitle,
                locale: locale,
                retryAction: retryAction
            )
        )
    }

    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        error: Error? = nil,
        locale: Locale?,
        retryAction: @escaping () -> Void
    ) {
        let content: ErrorContent = if let contentError = error as? ErrorContentConvertible {
            contentError.toErrorContent(for: locale)
        } else {
            ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.commonRequestRetry(preferredLanguages: locale?.rLanguages)
            )
        }

        presentRequestStatus(
            on: view,
            title: content.title,
            message: content.message,
            locale: locale,
            retryAction: retryAction
        )
    }

    func presentRequestStatus(
        on view: ControllerBackedProtocol?,
        error: Error? = nil,
        locale: Locale?,
        retryAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    ) {
        let content: ErrorContent = if let contentError = error as? ErrorContentConvertible {
            contentError.toErrorContent(for: locale)
        } else {
            ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.commonRequestRetry(preferredLanguages: locale?.rLanguages)
            )
        }

        presentRequestStatus(
            on: view,
            title: content.title,
            message: content.message,
            locale: locale,
            retryAction: retryAction,
            skipAction: skipAction
        )
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

struct RequestStatusAlertModel {
    let title: String
    let message: String
    let cancelAction: String?
    let locale: Locale?
    let retryAction: () -> Void
    let skipAction: (() -> Void)?

    init(
        title: String,
        message: String,
        cancelAction: String? = nil,
        locale: Locale?,
        retryAction: @escaping () -> Void,
        skipAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.cancelAction = cancelAction
        self.locale = locale
        self.retryAction = retryAction
        self.skipAction = skipAction
    }
}
