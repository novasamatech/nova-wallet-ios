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

    func presentPoolIsNotOpen(
        from view: ControllerBackedProtocol,
        locale: Locale
    )

    func presentPoolIsFull(
        from view: ControllerBackedProtocol,
        locale: Locale
    )

    func presentExistentialDepositViolation(
        from view: ControllerBackedProtocol,
        params: NPoolsEDViolationErrorParams,
        action: (() -> Void)?,
        locale: Locale
    )
}

extension NominationPoolErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNominationPoolHasNoApy(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable.commonNoRewardsTitle(preferredLanguages: locale?.rLanguages)
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
        let message = R.string.localizable.stakingPoolRewardsBondMorePoolIsDestroing(
            preferredLanguages: locale?.rLanguages)

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

    func presentPoolIsNotOpen(
        from view: ControllerBackedProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingPoolIsNotOpenTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingPoolIsNotOpenMessage(preferredLanguages: locale.rLanguages)

        present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }

    func presentPoolIsFull(
        from view: ControllerBackedProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingPoolIsFullTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingPoolIsFullMessage(preferredLanguages: locale.rLanguages)

        present(
            message: message,
            title: title,
            closeAction: R.string.localizable.commonClose(preferredLanguages: locale.rLanguages),
            from: view
        )
    }

    func presentExistentialDepositViolation(
        from view: ControllerBackedProtocol,
        params: NPoolsEDViolationErrorParams,
        action: (() -> Void)?,
        locale: Locale
    ) {
        let title = R.string.localizable.commonInsufficientBalance(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingPoolEdErrorMessage(
            params.availableBalance,
            params.minimumBalance,
            params.fee,
            params.maxStake,
            preferredLanguages: locale.rLanguages
        )

        let proceedTitle = R.string.localizable.stakingMaximumAction(preferredLanguages: locale.rLanguages)

        let actions: [AlertPresentableAction]

        if let action = action {
            let proceedAction = AlertPresentableAction(title: proceedTitle) {
                action()
            }

            actions = [proceedAction]
        } else {
            actions = []
        }

        let closeTitle = R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages)

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: actions,
            closeAction: closeTitle
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
