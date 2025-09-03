import Foundation

struct EvmGasValidatedParams {
    let maxPriorityFee: String
    let defaultFee: String
}

protocol EvmValidationErrorPresentable {
    func presentFeeToHigh(
        for view: ControllerBackedProtocol?,
        params: EvmGasValidatedParams,
        onRefresh: @escaping () -> Void,
        onProceed: @escaping () -> Void,
        locale: Locale
    )
}

extension EvmValidationErrorPresentable where Self: AlertPresentable {
    func presentFeeToHigh(
        for view: ControllerBackedProtocol?,
        params: EvmGasValidatedParams,
        onRefresh: @escaping () -> Void,
        onProceed: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string.localizable.evmTransactionFeeTooHighTitle(
            preferredLanguages: locale.rLanguages
        )

        let message = R.string.localizable.evmTransactionFeeTooHighMessage(
            params.maxPriorityFee,
            params.defaultFee,
            preferredLanguages: locale.rLanguages
        )

        let refreshAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonRefreshFee(),
            style: .normal
        ) {
            onRefresh()
        }

        let proceedAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonProceed(),
            style: .destructive
        ) {
            onProceed()
        }

        let model = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [refreshAction, proceedAction],
            closeAction: nil
        )

        present(viewModel: model, style: .alert, from: view)
    }
}
