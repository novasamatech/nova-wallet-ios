import Foundation

protocol FeeRetryable {
    func presentFeeStatus(
        on view: ControllerBackedProtocol?,
        locale: Locale?,
        retryAction: @escaping () -> Void
    )
}

extension FeeRetryable where Self: AlertPresentable {
    func presentFeeStatus(
        on view: ControllerBackedProtocol?,
        locale: Locale?,
        retryAction: @escaping () -> Void
    ) {
        let retryViewModel = AlertPresentableAction(
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonRetry(),
            handler: retryAction
        )

        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.commonFeeRetryFailed()

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [retryViewModel],
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonSkip()
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
