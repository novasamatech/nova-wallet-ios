import Foundation

protocol MythosStakingErrorPresentable: CollatorStakingErrorPresentable {
    func presentUnstakingItemsLimitReached(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?)
}

extension MythosStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentUnstakingItemsLimitReached(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.stakingUnbondingLimitReachedTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.unstakingLimitReachedMessage(
            maxAllowed
        )

        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
