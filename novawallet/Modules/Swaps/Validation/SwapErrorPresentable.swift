import Foundation

protocol SwapErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughLiquidity(from view: ControllerBackedProtocol, locale: Locale?)

    func presentRateUpdated(
        from view: ControllerBackedProtocol,
        oldRate: String,
        newRate: String,
        onConfirm: @escaping () -> Void,
        locale: Locale?
    )

    func presentInsufficientBalance(
        from view: ControllerBackedProtocol?,
        reason: SwapDisplayError.InsufficientBalance,
        action: @escaping () -> Void,
        locale: Locale
    )

    func presentDustRemains(
        from view: ControllerBackedProtocol?,
        reason: SwapDisplayError.DustRemains,
        swapMaxAction: @escaping () -> Void,
        proceedAction: @escaping () -> Void,
        locale: Locale
    )

    func presentHighPriceDifference(
        from view: ControllerBackedProtocol?,
        difference: String,
        proceedAction: @escaping () -> Void,
        locale: Locale
    )

    func presentNoProviderForNonSufficientToken(
        from view: ControllerBackedProtocol,
        utilityMinBalance: String,
        token: String,
        network: String,
        locale: Locale
    )

    func presentMinBalanceViolatedToReceive(
        from view: ControllerBackedProtocol,
        minBalance: String,
        locale: Locale
    )

    func presentMinBalanceViolatedAfterOperation(
        from view: ControllerBackedProtocol,
        minBalance: String,
        locale: Locale
    )

    func presentIntemediateAmountBelowMinimum(
        from view: ControllerBackedProtocol,
        amount: String,
        minAmount: String,
        locale: Locale
    )
}

extension SwapErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughLiquidity(from view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string(preferredLanguages: locale?.rLanguages).localizable.swapsSetupErrorNotEnoughLiquidityTitle()
        let closeAction = R.string(preferredLanguages: locale?.rLanguages).localizable.commonClose()

        present(message: nil, title: title, closeAction: closeAction, from: view)
    }

    func presentRateUpdated(
        from view: ControllerBackedProtocol,
        oldRate: String,
        newRate: String,
        onConfirm: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale?.rLanguages).localizable.swapsErrorRateWasUpdatedTitle()
        let message = R.string(preferredLanguages: locale?.rLanguages).localizable.swapsErrorRateWasUpdatedMessage(
            oldRate,
            newRate
        )

        let cancelAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale?.rLanguages).localizable.commonCancel()
        )

        let confirmAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale?.rLanguages).localizable.commonConfirm(),
            handler: onConfirm
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [cancelAction, confirmAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentNoProviderForNonSufficientToken(
        from view: ControllerBackedProtocol,
        utilityMinBalance: String,
        token: String,
        network: String,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.swapFailureCannotReceiveInsufficientAssetOut(
            utilityMinBalance,
            network,
            token
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMinBalanceViolatedToReceive(
        from view: ControllerBackedProtocol,
        minBalance: String,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.commonReceiveAtLeastEdError(
            minBalance
        )
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMinBalanceViolatedAfterOperation(
        from view: ControllerBackedProtocol,
        minBalance: String,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.swapDeliveryFeeErrorMessage(
            minBalance
        )
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentInsufficientBalance(
        from view: ControllerBackedProtocol?,
        reason: SwapDisplayError.InsufficientBalance,
        action: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string.localizable.commonInsufficientBalance(preferredLanguages: locale.rLanguages)
        let message: String

        switch reason {
        case let .dueFeePayAsset(value):
            message = R.string.localizable.commonNotEnoughToPayFeeMessage(
                value.fee,
                value.available,
                preferredLanguages: locale.rLanguages
            )
        case let .dueFeeNativeAsset(value):
            message = R.string.localizable.commonNotEnoughToPayFeeMessage(
                value.fee,
                value.available,
                preferredLanguages: locale.rLanguages
            )
        case let .dueConsumers(value):
            message = R.string.localizable.swapsViolatingConsumersMessage(
                value.minBalance,
                value.fee,
                preferredLanguages: locale.rLanguages
            )
        }

        let cancelAction = AlertPresentableAction(
            title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        let swapAllAction = AlertPresentableAction(
            title: R.string.localizable.commonSwapMax(preferredLanguages: locale.rLanguages),
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

    func presentDustRemains(
        from view: ControllerBackedProtocol?,
        reason: SwapDisplayError.DustRemains,
        swapMaxAction: @escaping () -> Void,
        proceedAction: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string.localizable.commonDustRemainsTitle(preferredLanguages: locale.rLanguages)
        let message: String

        switch reason {
        case let .dueSwap(value):
            message = R.string.localizable.swapsDustRemainsFeeNativeAssetMessage(
                value.minBalance,
                value.remaining,
                preferredLanguages: locale.rLanguages
            )
        }

        let proceedAction = AlertPresentableAction(
            title: R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages),
            handler: proceedAction
        )

        let swapAllAction = AlertPresentableAction(
            title: R.string.localizable.commonSwapMax(preferredLanguages: locale.rLanguages),
            handler: swapMaxAction
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [proceedAction, swapAllAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentHighPriceDifference(
        from view: ControllerBackedProtocol?,
        difference: String,
        proceedAction: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string.localizable.swapsMaxPriceDiffErrorTitle(difference, preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.swapsMaxPriceDiffErrorMessage(preferredLanguages: locale.rLanguages)

        let continueAction = AlertPresentableAction(
            title: R.string.localizable.commonProceed(preferredLanguages: locale.rLanguages),
            style: .destructive,
            handler: proceedAction
        )

        let cancelAction = AlertPresentableAction(
            title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [cancelAction, continueAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentIntemediateAmountBelowMinimum(
        from view: ControllerBackedProtocol,
        amount: String,
        minAmount: String,
        locale: Locale
    ) {
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.swapIntermediateTooLowAmountToStayAbowEdMessage(
            amount,
            minAmount,
            preferredLanguages: locale.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
