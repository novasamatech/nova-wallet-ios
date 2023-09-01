import Foundation

protocol NominationPoolErrorPresentable: BaseErrorPresentable {
    func presentNominationPoolHasNoApy(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )
    func presentNominationPoolIsDestroing(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )
    func presentPoolIsFullyUnbonding(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )
    func presentExistentialDeposit(
        from view: ControllerBackedProtocol,
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

    func presentNominationPoolIsDestroing(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.stakingPoolRewardsBondMorePoolIsDestroing(preferredLanguages: locale?.rLanguages)

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentPoolIsFullyUnbonding(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable.stakingPoolRewardsBondMorePoolUnbondingErrorTitle(
            preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.stakingPoolRewardsBondMorePoolUnbondingErrorMessage(
            preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentExistentialDeposit(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string.localizable
            .commonExistentialWarningTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .commonExistentialWarningMessage_v2_2_0(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
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
        let title = R.string.localizable.commonConfirmationTitle(preferredLanguages: locale.rLanguages)
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
