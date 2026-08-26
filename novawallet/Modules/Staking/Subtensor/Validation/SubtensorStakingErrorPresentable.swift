import Foundation

protocol SubtensorStakingErrorPresentable: BaseErrorPresentable {
    func presentPreflightNotReceived(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    )

    func presentQuoteMissing(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    )

    func presentStalePositions(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    )

    func presentOrderBeyondTolerance(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentHighPriceImpact(
        _ view: ControllerBackedProtocol,
        impact: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?)

    func presentStakeAllWarning(
        _ view: ControllerBackedProtocol,
        reserve: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentHotkeyNotFound(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentSubnetStakingDisabled(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentColdkeySwapInProgress(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentSafeModeActive(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentFeeFromStakeWarning(
        _ view: ControllerBackedProtocol,
        fee: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentUnstakeExceedsAvailable(_ view: ControllerBackedProtocol, available: String, locale: Locale?)

    func presentUnstakeAmountTooLow(_ view: ControllerBackedProtocol, minAmount: String, locale: Locale?)

    func presentDustRemainderWarning(
        _ view: ControllerBackedProtocol,
        remainder: String,
        minStake: String,
        action: @escaping () -> Void,
        unstakeAllAction: (() -> Void)?,
        locale: Locale?
    )

    func presentUnstakeLocked(_ view: ControllerBackedProtocol, eta: String, locale: Locale?)

    func presentClaimFirstAdvisory(
        _ view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentClaimFeeNotAvailable(_ view: ControllerBackedProtocol, fee: String, locale: Locale?)

    func presentClaimBelowThreshold(_ view: ControllerBackedProtocol, threshold: String, locale: Locale?)
}

extension SubtensorStakingErrorPresentable where Self: AlertPresentable & CommonRetryable {
    func presentPreflightNotReceived(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    ) {
        presentRequestStatus(on: view, locale: locale, retryAction: onRetry)
    }

    func presentQuoteMissing(
        _ view: ControllerBackedProtocol,
        onRetry: @escaping () -> Void,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentRequestStatus(
            on: view,
            title: strings.stakingSubtensorQuoteMissingTitle(),
            message: strings.stakingSubtensorQuoteMissingMessage(),
            locale: locale,
            retryAction: onRetry
        )
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

extension SubtensorStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    private func presentError(
        title: String,
        message: String,
        view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.amountTooLow(),
            message: strings.stakingSetupAmountTooLow(minStake),
            view: view,
            locale: locale
        )
    }

    func presentOrderBeyondTolerance(_ view: ControllerBackedProtocol, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorSelfImpactTitle(),
            message: strings.stakingSubtensorSelfImpactMessage(),
            view: view,
            locale: locale
        )
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

    func presentStakeAllWarning(
        _ view: ControllerBackedProtocol,
        reserve: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentWarning(
            for: strings.stakingSubtensorStakeAllWarningTitle(),
            message: strings.stakingSubtensorStakeAllWarningMessage(reserve),
            action: action,
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

    func presentSubnetStakingDisabled(_ view: ControllerBackedProtocol, locale: Locale?) {
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

    func presentFeeFromStakeWarning(
        _ view: ControllerBackedProtocol,
        fee: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentWarning(
            for: strings.stakingSubtensorFeeFromStakeTitle(),
            message: strings.stakingSubtensorFeeFromStakeMessage(fee),
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentUnstakeExceedsAvailable(
        _ view: ControllerBackedProtocol,
        available: String,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.commonAmountTooBig(),
            message: strings.stakingSubtensorUnstakeExceedsAvailableMessage(available),
            view: view,
            locale: locale
        )
    }

    func presentUnstakeAmountTooLow(_ view: ControllerBackedProtocol, minAmount: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.amountTooLow(),
            message: strings.stakingSubtensorUnstakeTooLowMessage(minAmount),
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
            title: strings.stakingSubtensorDustRemainderAction(),
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

    func presentUnstakeLocked(_ view: ControllerBackedProtocol, eta: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorUnstakeLockedTitle(),
            message: strings.stakingSubtensorUnstakeLockedMessage(eta),
            view: view,
            locale: locale
        )
    }

    func presentClaimFirstAdvisory(
        _ view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentWarning(
            for: strings.stakingSubtensorClaimFirstTitle(),
            message: strings.stakingSubtensorClaimFirstMessage(),
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentClaimFeeNotAvailable(_ view: ControllerBackedProtocol, fee: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorClaimFeeTitle(),
            message: strings.stakingSubtensorClaimFeeMessage(fee),
            view: view,
            locale: locale
        )
    }

    func presentClaimBelowThreshold(_ view: ControllerBackedProtocol, threshold: String, locale: Locale?) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        presentError(
            title: strings.stakingSubtensorClaimThresholdTitle(),
            message: strings.stakingSubtensorClaimThresholdMessage(threshold),
            view: view,
            locale: locale
        )
    }
}
