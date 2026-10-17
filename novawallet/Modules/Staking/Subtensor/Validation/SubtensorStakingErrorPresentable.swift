import Foundation

protocol SubtensorStakingErrorPresentable: SwapErrorPresentable {
    func presentError(title: String, message: String, view: ControllerBackedProtocol, locale: Locale?)

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

    func presentSubnetTradesUnavailable(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentDustRemainderWarning(
        _ view: ControllerBackedProtocol,
        remainder: String,
        minStake: String,
        action: @escaping () -> Void,
        unstakeAllAction: (() -> Void)?,
        locale: Locale?
    )
}

extension SubtensorStakingErrorPresentable where Self: AlertPresentable & CommonRetryable {
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

extension SubtensorStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
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
