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
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.amountTooLow()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingCollatorGreaterMinstkMessage(
            minStake
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentWontReceiveRewards(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonNoRewardsTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingCollatorGreaterMinstkMessage(
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

    func presentUnstakingAmountTooHigh(_ view: ControllerBackedProtocol, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.parastkCantUnstakeTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.parastkCantUnstakeAmountMessage()

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentWontReceiveRewardsAfterUnstaking(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonNoRewardsTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingCollatorLessMinstkMessage(
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

    func presentUnstakeAll(
        _ view: ControllerBackedProtocol,
        minStake: String,
        action: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.parastkUnstakeAllTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.parastkUnstakeAllMessageFormat(
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

    func presentNoUnstakingOptions(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.parastkUnstakeNoCollatorsTitle()

        let message = R.string(preferredLanguages: languages).localizable.parastkUnstakeNoCollatorsMessage()

        let close = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantRedeem(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.parastkCantRedeemTitle()

        let message = R.string(preferredLanguages: languages).localizable.parastkCantRedeemMessage()

        let close = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantRebond(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.parastkCantRebondTitle()

        let message = R.string(preferredLanguages: languages).localizable.parastkCantRebondMessage()

        let close = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantStakeMoreWhileRevoking(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.parastkCantBondMoreTitle()

        let message = R.string(preferredLanguages: languages).localizable.parastkPendingRevokeMessage()

        let close = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }

    func presentCantStakeInactiveCollator(_ view: ControllerBackedProtocol, locale: Locale?) {
        let languages = locale.rLanguages

        let title = R.string(preferredLanguages: languages).localizable.parastkNotActiveCollatorTitle()

        let message = R.string(preferredLanguages: languages).localizable.parastkNotActiveCollatorMessage()

        let close = R.string(preferredLanguages: languages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }
}
