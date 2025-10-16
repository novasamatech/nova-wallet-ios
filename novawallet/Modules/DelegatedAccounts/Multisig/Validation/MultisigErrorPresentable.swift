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
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.multisigValidationNotEnoughTokensTitle()

        let message = if let fee = params.fee {
            R.string(preferredLanguages: languages).localizable.multisigValidationInsuffisientBalanceMessage(
                params.signatoryName,
                fee,
                params.deposit,
                params.needToAdd
            )
        } else {
            R.string(preferredLanguages: languages).localizable.multisigValidationNotEnoughForDepositMessage(
                params.signatoryName,
                params.deposit,
                params.needToAdd
            )
        }

        let closeAction = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotEnoughBalanceForFee(
        from view: ControllerBackedProtocol,
        fee: String,
        needToAdd: String,
        signatoryName: String,
        locale: Locale?
    ) {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.multisigValidationNotEnoughTokensTitle()
        let message = R.string(preferredLanguages: languages).localizable.multisigValidationNotEnoughForFeeMessage(
            signatoryName,
            fee,
            needToAdd
        )

        let closeAction = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentOperationAlreadyAdded(
        from view: ControllerBackedProtocol?,
        multisigName: String,
        locale: Locale
    ) {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.multisigValidationAlreadyExistsTitle()

        let message = R.string(
            preferredLanguages: languages
        ).localizable.multisigValidationAlreadyExistsMessage(
            multisigName
        )

        let closeAction = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentOperationNotExist(
        from view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let languages = locale.rLanguages

        let title = R.string(
            preferredLanguages: languages
        ).localizable.multisigTransactionNotExistTitle()

        let message = R.string(
            preferredLanguages: languages
        ).localizable.multisigTransactionNotExistMessage()

        let closeAction = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
