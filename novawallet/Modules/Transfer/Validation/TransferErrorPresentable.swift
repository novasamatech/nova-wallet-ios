import Foundation

protocol TransferErrorPresentable: BaseErrorPresentable {
    func presentReceiverBalanceTooLow(from view: ControllerBackedProtocol, locale: Locale?)
    func presentNoReceiverAccount(
        for assetSymbol: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentSameReceiver(from view: ControllerBackedProtocol, locale: Locale?)
    func presentWrongChain(for chainName: String, from view: ControllerBackedProtocol, locale: Locale?)

    func presentCantPayCrossChainFee(
        from view: ControllerBackedProtocol,
        feeString: String,
        balance: String,
        locale: Locale?
    )

    func presentReceivedBlocked(from view: ControllerBackedProtocol?, locale: Locale?)

    func presentMinBalanceViolatedForDeliveryFee(
        from view: ControllerBackedProtocol,
        availableBalance: String,
        locale: Locale?
    )

    func presentKeepAliveViolatedForCrosschain(
        from view: ControllerBackedProtocol,
        minBalance: String,
        locale: Locale?
    )
}

extension TransferErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentReceiverBalanceTooLow(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.walletSendDeadRecipientTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.walletSendDeadRecipientMessage()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNoReceiverAccount(
        for assetSymbol: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletSendDeadRecipientCommissionAssetTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletSendDeadRecipientCommissionAssetMessage(
            assetSymbol
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentSameReceiver(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonValidationInvalidAddressTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonSameReceiveAddressMessage()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentReceivedBlocked(from view: ControllerBackedProtocol?, locale: Locale?) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletSendRecipientBlockedTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.walletSendRecipientBlockedMessage()

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentWrongChain(
        for chainName: String,
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonValidationInvalidAddressTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonValidationInvalidAddressMessage(chainName)

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentCantPayCrossChainFee(
        from view: ControllerBackedProtocol,
        feeString: String,
        balance: String,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonInsufficientBalance()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonNotEnoughCrosschainFeeMessage(
            feeString,
            balance
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMinBalanceViolatedForDeliveryFee(
        from view: ControllerBackedProtocol,
        availableBalance: String,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonInsufficientBalance()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.xcmDeliveryFeeEdErrorMessage(
            availableBalance
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentKeepAliveViolatedForCrosschain(
        from view: ControllerBackedProtocol,
        minBalance: String,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonInsufficientBalance()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.swapDeliveryFeeErrorMessage(
            minBalance
        )

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
