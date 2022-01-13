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
            title: R.string.localizable.commonRetry(preferredLanguages: locale?.rLanguages),
            handler: retryAction
        )

        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.commonFeeRetryFailed(preferredLanguages: locale?.rLanguages)

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [retryViewModel],
            closeAction: R.string.localizable.commonSkip(preferredLanguages: locale?.rLanguages)
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
