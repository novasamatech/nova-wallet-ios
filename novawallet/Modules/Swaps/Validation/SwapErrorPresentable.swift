import Foundation

protocol SwapErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughLiquidity(from view: ControllerBackedProtocol, locale: Locale?)
    func presentSwapAll(
        from view: ControllerBackedProtocol?,
        errorParams: SwapMaxErrorParams,
        action: @escaping () -> Void,
        locale: Locale
    )
}

extension SwapErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughLiquidity(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string.localizable.swapsSetupErrorNotEnoughLiquidityTitle(
            preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: locale?.rLanguages)

        present(message: nil, title: title, closeAction: closeAction, from: view)
    }

    func presentSwapAll(
        from view: ControllerBackedProtocol?,
        errorParams: SwapMaxErrorParams,
        action: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string.localizable.commonInsufficientBalance(preferredLanguages: locale.rLanguages)
        let message: String

        if let edError = errorParams.existentialDeposit {
            message = R.string.localizable.swapsSetupErrorInsufficientBalanceEdMessage(
                errorParams.maxSwap,
                errorParams.fee,
                edError.fee,
                edError.value,
                edError.token,
                preferredLanguages: locale.rLanguages
            )
        } else {
            message = R.string.localizable.swapsSetupErrorInsufficientBalanceMessage(
                errorParams.maxSwap,
                errorParams.fee,
                preferredLanguages: locale.rLanguages
            )
        }

        let cancelAction = AlertPresentableAction(
            title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        let swapAllAction = AlertPresentableAction(
            title: R.string.localizable.swapsSetupErrorInsufficientBalanceAction(
                preferredLanguages: locale.rLanguages
            ),
            handler: action
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [cancelAction, swapAllAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
