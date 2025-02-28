import Foundation

protocol ParachainStakingErrorPresentable: CollatorStakingErrorPresentable {
    func presentCantStakeCollator(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?)

    func presentUnstakingAmountTooHigh(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentWontReceiveRewards(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentWontReceiveRewardsAfterUnstaking(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentUnstakeAll(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    )

    func presentNoUnstakingOptions(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentCantRedeem(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentCantRebond(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentCantStakeMoreWhileRevoking(_ view: ControllerBackedProtocol, locale: Locale?)

    func presentCantStakeInactiveCollator(_ view: ControllerBackedProtocol, locale: Locale?)
}

extension ParachainStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentCantStakeCollator(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?) {
        let title = R.string.localizable.amountTooLow(preferredLanguages: locale?.rLanguages)

        let message = R.string.localizable.parachainStakingCollatorGreaterMinstkMessage(
            minStake,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentWontReceiveRewards(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable.commonNoRewardsTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.parachainStakingCollatorGreaterMinstkMessage(
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

    func presentUnstakingAmountTooHigh(_ view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string.localizable.parastkCantUnstakeTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.parastkCantUnstakeAmountMessage(preferredLanguages: locale?.rLanguages)

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentWontReceiveRewardsAfterUnstaking(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable.commonNoRewardsTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.parachainStakingCollatorLessMinstkMessage(
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

    func presentUnstakeAll(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string.localizable.parastkUnstakeAllTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.parastkUnstakeAllMessageFormat(
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

    func presentNoUnstakingOptions(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.parastkUnstakeNoCollatorsTitle(
            preferredLanguages: languages
        )

        let message = R.string.localizable.parastkUnstakeNoCollatorsMessage(
            preferredLanguages: languages
        )

        let close = R.string.localizable.commonClose(preferredLanguages: languages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantRedeem(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.parastkCantRedeemTitle(preferredLanguages: languages)

        let message = R.string.localizable.parastkCantRedeemMessage(preferredLanguages: languages)

        let close = R.string.localizable.commonClose(preferredLanguages: languages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantRebond(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.parastkCantRebondTitle(preferredLanguages: languages)

        let message = R.string.localizable.parastkCantRebondMessage(preferredLanguages: languages)

        let close = R.string.localizable.commonClose(preferredLanguages: languages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantStakeMoreWhileRevoking(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.parastkCantBondMoreTitle(preferredLanguages: languages)

        let message = R.string.localizable.parastkPendingRevokeMessage(preferredLanguages: languages)

        let close = R.string.localizable.commonClose(preferredLanguages: languages)

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantStakeInactiveCollator(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale?.rLanguages

        let title = R.string.localizable.parastkNotActiveCollatorTitle(preferredLanguages: languages)

        let message = R.string.localizable.parastkNotActiveCollatorMessage(preferredLanguages: languages)

        let close = R.string.localizable.commonClose(preferredLanguages: languages)

        present(message: message, title: title, closeAction: close, from: view)
    }
}
