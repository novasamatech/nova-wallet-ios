import Foundation

protocol MythosStakingErrorPresentable: CollatorStakingErrorPresentable {
    func presentUnstakingItemsLimitReached(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?)
}

extension MythosStakingErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentUnstakingItemsLimitReached(_ view: ControllerBackedProtocol, maxAllowed: String, locale: Locale?) {
        let title = R.string.localizable.stakingUnbondingLimitReachedTitle(
            preferredLanguages: locale?.rLanguages
        )

        let message = R.string.localizable.unstakingLimitReachedMessage(
            maxAllowed,
            preferredLanguages: locale?.rLanguages
        )

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
