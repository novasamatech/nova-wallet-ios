import Foundation

struct NPoolsEDViolationErrorParams {
    let availableBalance: String
    let minimumBalance: String
    let fee: String
    let maxStake: String
}

protocol StakingErrorPresentable: BaseErrorPresentable {
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

    func presentStashKilledAfterUnbond(
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

    func presentMaxNumberOfNominatorsReached(from view: ControllerBackedProtocol?, locale: Locale?)

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
}

extension StakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentAmountTooLow(value: String, from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable.stakingSetupAmountTooLow(value, preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.amountTooLow(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMissingController(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    ) {
        let message = R.string.localizable
            .stakingAddController(address, preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMissingStash(
        from view: ControllerBackedProtocol,
        address: AccountAddress,
        locale: Locale?
    ) {
        let message = R.string.localizable
            .stakingStashMissingMessage(address, preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentUnbondingTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable
            .stakingRedeemNoTokensMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .commonInsufficientBalance(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentRebondingTooHigh(from view: ControllerBackedProtocol, locale: Locale?) {
        let message = R.string.localizable
            .stakingRebondInsufficientBondings(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .commonInsufficientBalance(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentRewardIsLessThanFee(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable
            .commonConfirmationTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingWarningTinyPayout(preferredLanguages: locale?.rLanguages)

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
        let title = R.string.localizable
            .commonConfirmationTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingControllerAccountZeroBalance(preferredLanguages: locale?.rLanguages)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentStashKilledAfterUnbond(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable
            .stakingUnbondingAllTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingUnbondingAllMessage(preferredLanguages: locale?.rLanguages)

        presentWarning(for: title, message: message, action: action, view: view, locale: locale)
    }

    func presentUnbondingLimitReached(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable.stakingUnbondingLimitReachedTitle(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNoRedeemables(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable
            .stakingRedeemNoTokensMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentControllerIsAlreadyUsed(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable.stakingAccountIsUsedAsController(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentDeselectValidatorsWarning(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable
            .commonConfirmationTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingCustomDeselectWarning(preferredLanguages: locale?.rLanguages)

        presentWarning(
            for: title,
            message: message,
            action: action,
            view: view,
            locale: locale
        )
    }

    func presentMaxNumberOfNominatorsReached(from view: ControllerBackedProtocol?, locale: Locale?) {
        let message = R.string.localizable.stakingMaxNominatorsReachedMessage(
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.stakingMaxNominatorsReachedTitle(
            preferredLanguages: locale?.rLanguages
        )
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMinRewardableStakeViolated(
        from view: ControllerBackedProtocol,
        action: @escaping () -> Void,
        minStake: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.amountTooLow(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.stakingMinStakeViolatedMessage(
            minStake,
            preferredLanguages: locale?.rLanguages
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
        let message = R.string.localizable.stakingLockedPoolViolationError(
            lockReason,
            availableToStake,
            directRewardableToStake,
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.stakingLockedPoolViolationTitle(
            preferredLanguages: locale?.rLanguages
        )
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
