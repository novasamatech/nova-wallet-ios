import Foundation

protocol TransferErrorPresentable: BaseErrorPresentable {
    func presentCantPayFee(from view: ControllerBackedProtocol, locale: Locale?)
    func presentReceiverBalanceTooLow(from view: ControllerBackedProtocol, locale: Locale?)
    func presentNoReceiverAccount(
        for assetSymbol: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentSameReceiver(from view: ControllerBackedProtocol, locale: Locale?)
    func presentWrongChain(for chainName: String, from view: ControllerBackedProtocol, locale: Locale?)
}

extension TransferErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentCantPayFee(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string.localizable.amountTooLow(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.walletFeeOverExistentialDeposit(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentReceiverBalanceTooLow(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string.localizable.walletSendDeadRecipientTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.walletSendDeadRecipientMessage(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNoReceiverAccount(
        for assetSymbol: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.walletSendDeadRecipientCommissionAssetTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.walletSendDeadRecipientCommissionAssetMessage(
            assetSymbol,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentSameReceiver(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string.localizable.commonValidationInvalidAddressTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.commonSameReceiveAddressMessage(
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentWrongChain(
        for chainName: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.commonValidationInvalidAddressTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.commonValidationInvalidAddressMessage(
            chainName,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
