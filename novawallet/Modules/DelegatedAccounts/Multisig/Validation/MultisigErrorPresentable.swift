import Foundation

protocol MultisigErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughBalanceForDepositAndFee(
        from view: ControllerBackedProtocol,
        deposit: String,
        fee: String,
        remaining: String,
        accountName: String,
        locale: Locale?
    )

    func presentNotEnoughBalanceForDeposit(
        from view: ControllerBackedProtocol,
        deposit: String,
        remaining: String,
        accountName: String,
        locale: Locale?
    )

    func presentNotEnoughBalanceForFee(
        from view: ControllerBackedProtocol,
        fee: String,
        remaining: String,
        accountName: String,
        locale: Locale?
    )

    func presentOperationAlreadyAdded(
        from view: ControllerBackedProtocol?,
        accountName: String,
        locale: Locale
    )
}

extension MultisigErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughBalanceForDepositAndFee(
        from view: ControllerBackedProtocol,
        deposit: String,
        fee: String,
        remaining: String,
        accountName: String,
        locale: Locale?
    ) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.multisigValidationNotEnoughTokensTitle(
            preferredLanguages: languages
        )
        let message = R.string.localizable.multisigValidationInsuffisientBalanceMessage(
            accountName,
            fee,
            deposit,
            remaining,
            preferredLanguages: languages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForDeposit(
        from view: ControllerBackedProtocol,
        deposit: String,
        remaining: String,
        accountName: String,
        locale: Locale?
    ) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.multisigValidationNotEnoughTokensTitle(
            preferredLanguages: locale?.rLanguages
        )
        let message = R.string.localizable.multisigValidationNotEnoughForDepositMessage(
            accountName,
            deposit,
            remaining,
            preferredLanguages: languages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForFee(
        from view: ControllerBackedProtocol,
        fee: String,
        remaining: String,
        accountName: String,
        locale: Locale?
    ) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.multisigValidationNotEnoughTokensTitle(
            preferredLanguages: locale?.rLanguages
        )
        let message = R.string.localizable.multisigValidationNotEnoughForFeeMessage(
            accountName,
            fee,
            remaining,
            preferredLanguages: languages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

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
}
