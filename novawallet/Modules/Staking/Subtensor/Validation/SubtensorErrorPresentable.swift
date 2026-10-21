import Foundation

protocol SubtensorErrorPresentable: SwapErrorPresentable {
    func presentPreflightNotReceived(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    )

    func presentStalePositions(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    )

    func presentHighPriceImpact(
        _ view: ControllerBackedProtocol,
        impact: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentInactiveValidator(_ view: ControllerBackedProtocol, action: @escaping () -> Void, locale: Locale?)

    func presentSubnetTradesUnavailable(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentDustRemainderWarning(
        _ view: ControllerBackedProtocol,
        remainder: String,
        minStake: String,
        action: @escaping () -> Void,
        unstakeAllAction: (() -> Void)?,
        locale: Locale?
    )

    func presentSelfImpact(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentFeeReserveViolated(
        _ view: ControllerBackedProtocol,
        maxAmount: String,
        reserve: String,
        locale: Locale?
    )

    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minimum: String, locale: Locale?)

    func presentHotkeyNotFound(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentSubnetDisabled(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentColdkeySwapInProgress(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentSafeModeActive(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentUnstakeLocked(_ view: ControllerBackedProtocol, eta: String, locale: Locale?)

    func presentSellExceedsAvailable(_ view: ControllerBackedProtocol, available: String, locale: Locale?)

    func presentSellBelowMinimum(_ view: ControllerBackedProtocol, minimum: String, locale: Locale?)

    func presentRemainderLocked(
        _ view: ControllerBackedProtocol,
        remainder: String,
        minStake: String,
        locale: Locale?
    )
}

extension SubtensorErrorPresentable where Self: AlertPresentable & CommonRetryable {
    func presentPreflightNotReceived(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    ) {
        presentRequestStatus(on: view, locale: locale, retryAction: onRetry)
    }

    func presentStalePositions(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentRequestStatus(
            on: view,
            title: strings.stakingSubtensorAlertStaleTitle(),
            message: strings.stakingSubtensorAlertStaleMessage(),
            locale: locale,
            retryAction: onRetry
        )
    }
}

extension SubtensorErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentError(title: String, message: String, view: ControllerBackedProtocol, locale: Locale?) {
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentHighPriceImpact(
        _ view: ControllerBackedProtocol,
        impact: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let proceedAction = AlertPresentableAction(
            title: strings.commonProceed(),
            style: .destructive,
            handler: action
        )

        let cancelAction = AlertPresentableAction(title: strings.commonCancel())

        let viewModel = AlertPresentableViewModel(
            title: strings.stakingSubtensorPriceImpactWarningTitle(),
            message: strings.stakingSubtensorPriceImpactWarningMessage(impact),
            actions: [cancelAction, proceedAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentInactiveValidator(_ view: ControllerBackedProtocol, action: @escaping () -> Void, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        let viewModel = AlertPresentableViewModel(
            title: strings.stakingSubtensorUiValidatorInactiveTitle(),
            message: strings.stakingSubtensorUiValidatorInactiveMessage(),
            actions: [
                AlertPresentableAction(title: strings.commonCancel()),
                AlertPresentableAction(title: strings.commonContinue(), handler: action)
            ],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentSubnetTradesUnavailable(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorTradesUnavailableTitle(),
            message: strings.stakingSubtensorErrorNovaFeeUnavailable(),
            view: view,
            locale: locale
        )
    }

    func presentDustRemainderWarning(
        _ view: ControllerBackedProtocol,
        remainder: String,
        minStake: String,
        action: @escaping () -> Void,
        unstakeAllAction: (() -> Void)?,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        guard let unstakeAllAction else {
            presentWarning(
                for: strings.stakingSubtensorDustRemainderTitle(),
                message: strings.stakingSubtensorDustRemainderMessage(remainder, minStake),
                action: action,
                view: view,
                locale: locale
            )

            return
        }

        let proceedAction = AlertPresentableAction(title: strings.commonProceed(), handler: action)

        let closeAllAction = AlertPresentableAction(
            title: strings.stakingUnstakeAll(),
            style: .destructive,
            handler: unstakeAllAction
        )

        let viewModel = AlertPresentableViewModel(
            title: strings.stakingSubtensorDustRemainderTitle(),
            message: strings.stakingSubtensorDustRemainderMessage(remainder, minStake),
            actions: [proceedAction, closeAllAction],
            closeAction: strings.commonCancel()
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}

extension SubtensorErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentSelfImpact(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorSelfImpactTitle(),
            message: strings.stakingSubtensorSelfImpactMessage(),
            view: view,
            locale: locale
        )
    }

    func presentFeeReserveViolated(
        _ view: ControllerBackedProtocol,
        maxAmount: String,
        reserve: String,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorReserveTitle(reserve),
            message: strings.stakingSubtensorReserveMessage(maxAmount, reserve),
            view: view,
            locale: locale
        )
    }

    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minimum: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.amountTooLow(),
            message: strings.stakingSetupAmountTooLow(minimum),
            view: view,
            locale: locale
        )
    }

    func presentHotkeyNotFound(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorHotkeyNotFoundTitle(),
            message: strings.stakingSubtensorHotkeyNotFoundMessage(),
            view: view,
            locale: locale
        )
    }

    func presentSubnetDisabled(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorSubnetDisabledTitle(),
            message: strings.stakingSubtensorSubnetDisabledMessage(),
            view: view,
            locale: locale
        )
    }

    func presentColdkeySwapInProgress(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorColdkeySwapTitle(),
            message: strings.stakingSubtensorColdkeySwapMessage(),
            view: view,
            locale: locale
        )
    }

    func presentSafeModeActive(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorSafeModeTitle(),
            message: strings.stakingSubtensorSafeModeMessage(),
            view: view,
            locale: locale
        )
    }

    func presentUnstakeLocked(_ view: ControllerBackedProtocol, eta: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorUnstakeLockedTitle(),
            message: strings.stakingSubtensorUnstakeLockedMessage(eta),
            view: view,
            locale: locale
        )
    }

    func presentSellExceedsAvailable(_ view: ControllerBackedProtocol, available: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.commonAmountTooBig(),
            message: strings.stakingSubtensorUnstakeExceedsAvailableMessage(available),
            view: view,
            locale: locale
        )
    }

    func presentSellBelowMinimum(_ view: ControllerBackedProtocol, minimum: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.amountTooLow(),
            message: strings.stakingSubtensorUnstakeTooLowMessage(minimum),
            view: view,
            locale: locale
        )
    }

    func presentRemainderLocked(
        _ view: ControllerBackedProtocol,
        remainder: String,
        minStake: String,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorRemainderLockedTitle(),
            message: strings.stakingSubtensorRemainderLockedMessage(remainder, minStake),
            view: view,
            locale: locale
        )
    }
}
