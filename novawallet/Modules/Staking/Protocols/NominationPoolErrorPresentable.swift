import Foundation

struct NPoolsEDViolationErrorParams {
    let availableBalance: String
    let minimumBalance: String
    let fee: String
    let maxStake: String
}

protocol NominationPoolErrorPresentable: StakingBaseErrorPresentable {
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

    func presentDirectStakingNotAllowedForMigration(
        from view: ControllerBackedProtocol,
        locale: Locale
    )
}

extension NominationPoolErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNominationPoolHasNoApy(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonNoRewardsTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingPoolHasNoApyMessage()

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
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingPoolRewardsBondMorePoolIsDestroing()

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()
        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentPoolIsFullyUnbonding(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingPoolRewardsBondMorePoolUnbondingErrorTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingPoolRewardsBondMorePoolUnbondingErrorMessage()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentUnstakeAmountToHigh(from view: ControllerBackedProtocol?, locale: Locale) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonInsufficientBalance()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnstakeTooHighMessage()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }

    func presentNoUnstakeSpace(
        from view: ControllerBackedProtocol?,
        unstakeAfter: String,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnstakeNoSpaceTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnstakeNoSpaceMessage(
            "~\(unstakeAfter)"
        )

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }

    func presentNoProfitAfterClaimRewards(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonConfirmationTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingWarningTinyPayout()

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
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingPoolIsNotOpenTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingPoolIsNotOpenMessage()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }

    func presentPoolIsFull(
        from view: ControllerBackedProtocol,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingPoolIsFullTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingPoolIsFullMessage()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }

    func presentExistentialDepositViolation(
        from view: ControllerBackedProtocol,
        params: NPoolsEDViolationErrorParams,
        action: (() -> Void)?,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonInsufficientBalance()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingPoolEdErrorMessage(
            params.availableBalance,
            params.minimumBalance,
            params.fee,
            params.maxStake
        )

        let proceedTitle = R.string(preferredLanguages: locale.rLanguages).localizable.stakingMaximumAction()

        let actions: [AlertPresentableAction]

        if let action = action {
            let proceedAction = AlertPresentableAction(title: proceedTitle) {
                action()
            }

            actions = [proceedAction]
        } else {
            actions = []
        }

        let closeTitle = R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: actions,
            closeAction: closeTitle
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentDirectStakingNotAllowedForMigration(
        from view: ControllerBackedProtocol,
        locale: Locale
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.nominationPoolsConflictTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.nominationPoolsConflictMessage()

        present(
            message: message,
            title: title,
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            from: view
        )
    }
}
