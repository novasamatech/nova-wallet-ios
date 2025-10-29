import Foundation

protocol StakingErrorPresentable: StakingBaseErrorPresentable {
    func presentAmountTooLow(value: String, from view: ControllerBackedProtocol, locale: Locale?)

    func presentMissingController(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    )

    func presentMissingStash(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    )

    func presentUnbondingTooHigh(from view: ControllerBackedProtocol, locale: Locale?)
    func presentRebondingTooHigh(from view: ControllerBackedProtocol, locale: Locale?)

    func presentRewardIsLessThanFee(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentControllerBalanceIsZero(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentUnbondingLimitReached(from view: ControllerBackedProtocol?, locale: Locale?)
    func presentNoRedeemables(from view: ControllerBackedProtocol?, locale: Locale?)
    func presentControllerIsAlreadyUsed(from view: ControllerBackedProtocol?, locale: Locale?)

    func presentDeselectValidatorsWarning(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentMaxNumberOfNominatorsReached(
        from view: ControllerBackedProtocol?,
        stakingType: String,
        locale: Locale?
    )

    func presentMinRewardableStakeViolated(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        minStake: String,
        locale: Locale?
    )

    func presentLockedTokensInPoolStaking(
        from view: ControllerBackedProtocol?,
        lockReason: String,
        availableToStake: String,
        directRewardableToStake: String,
        locale: Locale?
    )

    func presentAlreadyHaveStaking(
        from view: ControllerBackedProtocol?,
        networkName: String,
        onClose: @escaping () -> Void,
        locale: Locale?
    )

    func presentDirectAndPoolStakingConflict(
        from view: ControllerBackedProtocol?,
        locale: Locale?
    )
}

extension StakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentAmountTooLow(value: String, from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetupAmountTooLow(value)
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.amountTooLow()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMissingController(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingAddController(address)
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMissingStash(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingStashMissingMessage(address)
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentUnbondingTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingRedeemNoTokensMessage()
        let title = R.string(preferredLanguages: locale.rLanguages)
            .localizable.commonInsufficientBalance()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentRebondingTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingRebondInsufficientBondings()
        let title = R.string(preferredLanguages: locale.rLanguages)
            .localizable.commonInsufficientBalance()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentRewardIsLessThanFee(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages)
            .localizable.commonConfirmationTitle()
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingWarningTinyPayout()

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentControllerBalanceIsZero(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages)
            .localizable.commonConfirmationTitle()
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingControllerAccountZeroBalance()

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentUnbondingLimitReached(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnbondingLimitReachedTitle()
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNoRedeemables(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingRedeemNoTokensMessage()
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentControllerIsAlreadyUsed(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingAccountIsUsedAsController()
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonErrorGeneralTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentDeselectValidatorsWarning(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages)
            .localizable.commonConfirmationTitle()
        let message = R.string(preferredLanguages: locale.rLanguages)
            .localizable.stakingCustomDeselectWarning()

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentMaxNumberOfNominatorsReached(
        from view: ControllerBackedProtocol?,
        stakingType: String,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingMaxNominatorsReachedMessage()

        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingIsNotAvailableTitle(
            stakingType
        )
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMinRewardableStakeViolated(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        minStake: String,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.amountTooLow()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingMinStakeViolatedMessage(
            minStake
        )

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentLockedTokensInPoolStaking(
        from view: ControllerBackedProtocol?,
        lockReason: String,
        availableToStake: String,
        directRewardableToStake: String,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingLockedPoolViolationError(
            lockReason,
            availableToStake,
            directRewardableToStake,
            lockReason
        )

        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingLockedPoolViolationTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentAlreadyHaveStaking(
        from view: ControllerBackedProtocol?,
        networkName: String,
        onClose: @escaping () -> Void,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartAlreadyHaveAnyStaking(
            networkName
        )

        let closeAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonClose(),
            handler: onClose
        )

        let viewModel = AlertPresentableViewModel(
            title: nil,
            message: message,
            actions: [closeAction],
            closeAction: nil
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }

    func presentDirectAndPoolStakingConflict(
        from view: ControllerBackedProtocol?,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetupConflictMessage()

        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetupConflictTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
