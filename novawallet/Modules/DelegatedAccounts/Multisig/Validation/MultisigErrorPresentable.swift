import Foundation

protocol MultisigErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughBalanceForDeposit(
        from view: ControllerBackedProtocol,
        deposit: String,
        balance: String,
        accountName: String,
        locale: Locale?
    )

    func presentOperationAlreadyAdded(
        from view: ControllerBackedProtocol?,
        accountName: String,
        locale: Locale
    )

    func presentNotValidAddress(
        from view: ControllerBackedProtocol,
        networkName: String,
        locale: Locale?
    )

    func presentFeeTooHigh(
        from view: ControllerBackedProtocol,
        balance: String,
        fee: String,
        accountName: String,
        locale: Locale?
    )
}

extension MultisigErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughBalanceForDeposit(
        from view: ControllerBackedProtocol,
        deposit: String,
        balance: String,
        accountName _: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.stakingSetupProxyErrorInsufficientBalanceTitle(
            preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.stakingSetupProxyErrorInsufficientBalanceMessage(
            deposit,
            balance,
            preferredLanguages: locale?.rLanguages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentOperationAlreadyAdded(
        from view: ControllerBackedProtocol?,
        accountName: String,
        locale: Locale
    ) {
        let languages = locale.rLanguages

        let title = R.string.localizable.multisigValidationNotEnoughTokensTitle(
            preferredLanguages: languages
        )
        let message = R.string.localizable.multisigValidationAlreadyExistsMessage(
            accountName,
            preferredLanguages: languages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentFeeTooHigh(
        from view: ControllerBackedProtocol,
        balance: String,
        fee: String,
        accountName: String,
        locale: Locale?
    ) {
        let message = R.string.localizable.proxyFeeErrorMessage(
            accountName,
            fee,
            balance,
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.commonNotEnoughFeeTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
