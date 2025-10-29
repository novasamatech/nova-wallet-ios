import Foundation

protocol CollatorStakingErrorPresentable: BaseErrorPresentable {
    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?)
    func presentDelegatorFull(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?)
}

extension CollatorStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentDelegatorFull(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingFullTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.parachainStakingFullMessage(
            maxAllowed
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentStakeAmountTooLow(_ view: ControllerBackedProtocol, minStake: String, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.amountTooLow()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.stakingSetupAmountTooLow(
            minStake
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
