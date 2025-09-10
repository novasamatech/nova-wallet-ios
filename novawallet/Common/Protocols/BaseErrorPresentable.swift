import Foundation

protocol BaseErrorPresentable {
    func presentAmountTooHigh(from view: ControllerBackedProtocol, locale: Locale?)
    func presentFeeNotReceived(from view: ControllerBackedProtocol, locale: Locale?)
    func presentFeeTooHigh(from view: ControllerBackedProtocol, balance: String, fee: String, locale: Locale?)
    func presentExtrinsicFailed(from view: ControllerBackedProtocol, locale: Locale?)
    func presentInvalidAddress(from view: ControllerBackedProtocol, chainName: String, locale: Locale?)
    func presentUpToForFee(
        from view: ControllerBackedProtocol,
        available: String,
        fee: String,
        maxClosure: (() -> Void)?,
        locale: Locale?
    )

    func presentExistentialDepositWarning(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentIsSystemAccount(
        from view: ControllerBackedProtocol?,
        onContinue: @escaping () -> Void,
        locale: Locale?
    )

    func presentMinBalanceViolated(
        from view: ControllerBackedProtocol,
        minBalanceForOperation: String,
        currentBalance: String,
        needToAddBalance: String,
        locale: Locale?
    )
}

extension BaseErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentAmountTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonNotEnoughBalanceMessage()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonErrorGeneralTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentFeeNotReceived(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.feeNotYetLoadedMessage()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.feeNotYetLoadedTitle()
        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentExtrinsicFailed(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonTransactionFailed()
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonErrorGeneralTitle()
        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentFeeTooHigh(from view: ControllerBackedProtocol, balance: String, fee: String, locale: Locale?) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonNotEnoughFeeMessage_v380(
            fee,
            balance
        )

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonNotEnoughFeeTitle()
        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentUpToForFee(
        from view: ControllerBackedProtocol,
        available: String,
        fee: String,
        maxClosure: (() -> Void)?,
        locale: Locale?
    ) {
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonUseMaxDueFeeMessage(
            available,
            fee
        )

        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonInsufficientBalance()

        if let maxClosure {
            let cancelTitle = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonCancel()

            let maxTitle = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.swipeGovAmountAlertUseMax()

            let viewModel = AlertPresentableViewModel(
                title: title,
                message: message,
                actions: [
                    .init(title: cancelTitle),
                    .init(title: maxTitle, handler: maxClosure)
                ],
                closeAction: nil
            )

            present(viewModel: viewModel, style: .alert, from: view)
        } else {
            let closeAction = R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonClose()

            present(message: message, title: title, closeAction: closeAction, from: view)
        }
    }

    func presentExistentialDepositWarning(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonExistentialWarningTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonExistentialWarningMessage_v2_2_0()

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentWarning(
        for title: String,
        message: String,
        action: @escaping () -> Void,
        view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let proceedTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonProceed()
        let proceedAction = AlertPresentableAction(title: proceedTitle) {
            action()
        }

        let closeTitle = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonCancel()

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [proceedAction],
            closeAction: closeTitle
        )

        present(
            viewModel: viewModel,
            style: .alert,
            from: view
        )
    }

    func presentInvalidAddress(from view: ControllerBackedProtocol, chainName: String, locale: Locale?) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonValidationInvalidAddressTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonInvalidAddressFormat(chainName)

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentIsSystemAccount(
        from view: ControllerBackedProtocol?,
        onContinue: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.sendSystemAccountTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.sendSystemAccountMessage()

        let continueAction = AlertPresentableAction(
            title: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonContinue(),
            style: .destructive
        ) {
            onContinue()
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [continueAction],
            closeAction: R.string(
                preferredLanguages: locale.rLanguages
            ).localizable.commonCancel()
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentMinBalanceViolated(
        from view: ControllerBackedProtocol,
        minBalanceForOperation: String,
        currentBalance: String,
        needToAddBalance: String,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.amountTooLow()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.transactionMinBalanceViolationMessage(
            minBalanceForOperation,
            currentBalance,
            needToAddBalance
        )

        let closeAction = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
