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
                title: R.string(preferredLanguages: viewModel.locale.rLanguages).localizable.commonRetry(),
                handler: viewModel.retryAction
            )
        ]

        if let skipAction = viewModel.skipAction {
            let skipViewModel = AlertPresentableAction(
                title: R.string(
                    preferredLanguages: viewModel.locale.rLanguages
                ).localizable.commonSkip(),
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
        let cancelActionTitle = cancelAction ?? R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonSkip()

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
        locale: Locale?,
        retryAction: @escaping () -> Void
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.commonRequestRetry()

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
        locale: Locale?,
        retryAction: @escaping () -> Void,
        skipAction: @escaping () -> Void
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.commonRequestRetry()

        presentRequestStatus(
            on: view,
            title: title,
            message: message,
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
