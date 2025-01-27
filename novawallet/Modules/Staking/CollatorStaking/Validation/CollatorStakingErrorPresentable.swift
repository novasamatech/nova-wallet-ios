import Foundation

protocol CollatorStakingErrorPresentable: BaseErrorPresentable {
    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?)
    func presentDelegatorFull(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?)
}

extension CollatorStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentDelegatorFull(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?) {
        let title = R.string.localizable.parachainStakingFullTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.parachainStakingFullMessage(
            maxAllowed,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?) {
        let title = R.string.localizable.amountTooLow(preferredLanguages: locale?.rLanguages)

        let message = R.string.localizable.stakingSetupAmountTooLow(
            minStake,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
