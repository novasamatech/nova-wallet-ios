import Foundation

struct MultisigNotEnoughForDeposit {
    let deposit: String
    let fee: String?
    let needToAdd: String
    let signatoryName: String
}

protocol MultisigErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughBalanceForDepositAndFee(
        from view: ControllerBackedProtocol,
        params: MultisigNotEnoughForDeposit,
        locale: Locale?
    )

    func presentNotEnoughBalanceForFee(
        from view: ControllerBackedProtocol,
        fee: String,
        needToAdd: String,
        signatoryName: String,
        locale: Locale?
    )

    func presentOperationAlreadyAdded(
        from view: ControllerBackedProtocol?,
        multisigName: String,
        locale: Locale
    )

    func presentOperationNotExist(
        from view: ControllerBackedProtocol?,
        locale: Locale
    )
}

extension MultisigErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughBalanceForDepositAndFee(
        from view: ControllerBackedProtocol,
        params: MultisigNotEnoughForDeposit,
        locale: Locale?
    ) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.multisigValidationNotEnoughTokensTitle(
            preferredLanguages: languages
        )
        let message = if let fee = params.fee {
            R.string.localizable.multisigValidationInsuffisientBalanceMessage(
                params.signatoryName,
                fee,
                params.deposit,
                params.needToAdd,
                preferredLanguages: languages
            )
        } else {
            R.string.localizable.multisigValidationNotEnoughForDepositMessage(
                params.signatoryName,
                params.deposit,
                params.needToAdd,
                preferredLanguages: languages
            )
        }

        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForFee(
        from view: ControllerBackedProtocol,
        fee: String,
        needToAdd: String,
        signatoryName: String,
        locale: Locale?
    ) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.multisigValidationNotEnoughTokensTitle(
            preferredLanguages: locale?.rLanguages
        )
        let message = R.string.localizable.multisigValidationNotEnoughForFeeMessage(
            signatoryName,
            fee,
            needToAdd,
            preferredLanguages: languages
        )

        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentOperationAlreadyAdded(
        from view: ControllerBackedProtocol?,
        multisigName: String,
        locale: Locale
    ) {
        let languages = locale.rLanguages

        let title = R.string.localizable.multisigValidationAlreadyExistsTitle(
            preferredLanguages: languages
        )

        let message = R.string.localizable.multisigValidationAlreadyExistsMessage(
            multisigName,
            preferredLanguages: languages
        )

        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentOperationNotExist(
        from view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let languages = locale.rLanguages

        let title = R.string.localizable.multisigTransactionNotExistTitle(
            preferredLanguages: languages
        )

        let message = R.string.localizable.multisigTransactionNotExistMessage(
            preferredLanguages: languages
        )

        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: languages
        )

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
