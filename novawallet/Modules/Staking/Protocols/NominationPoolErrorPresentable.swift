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
}
