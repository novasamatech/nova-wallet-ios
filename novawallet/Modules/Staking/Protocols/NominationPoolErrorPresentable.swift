import Foundation

protocol NominationPoolErrorPresentable: BaseErrorPresentable {
    func presentNominationPoolHasNoApy(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentUnstakeAmountToHigh(from view: ControllerBackedProtocol?, locale: Locale)

    func presentNoUnstakeSpace(
        from view: ControllerBackedProtocol?,
        unstakeAfter: String,
        locale: Locale
    )

    func presentCrossedMinStake(
        from view: ControllerBackedProtocol?,
        minStake: String,
        remaining: String,
        action: @escaping () -> Void,
        locale: Locale
    )

    func presentNoProfitAfterClaimRewards(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale
    )
}

extension NominationPoolErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNominationPoolHasNoApy(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable.stakingPoolHasNoApyTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.stakingPoolHasNoApyMessage(preferredLanguages: locale?.rLanguages)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentUnstakeAmountToHigh(from view: ControllerBackedProtocol?, locale: Locale) {
        let title = R.string.localizable.commonInsufficientBalance(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingUnstakeTooHighMessage(preferredLanguages: locale.rLanguages)

        present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }

    func presentNoUnstakeSpace(
        from view: ControllerBackedProtocol?,
        unstakeAfter: String,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingUnstakeNoSpaceTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingUnstakeNoSpaceMessage(
            "~\(unstakeAfter)",
            preferredLanguages: locale.rLanguages
        )

        present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }

    func presentCrossedMinStake(
        from view: ControllerBackedProtocol?,
        minStake: String,
        remaining: String,
        action: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingUnstakeCrossedMinTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingUnstakeCrossedMinMessage(
            minStake,
            remaining,
            preferredLanguages: locale.rLanguages
        )

        let cancelAction = AlertPresentableAction(
            title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)
        )

        let unstakeAllAction = AlertPresentableAction(
            title: R.string.localizable.stakingUnstakeAll(preferredLanguages: locale.rLanguages),
            handler: action
        )

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [cancelAction, unstakeAllAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentNoProfitAfterClaimRewards(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string.localizable.commonConfirmTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingWarningTinyPayout(preferredLanguages: locale.rLanguages)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }
}
