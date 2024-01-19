import Foundation

protocol ProxyErrorPresentable: BaseErrorPresentable {
    func presentFeeTooHigh(
        from view: ControllerBackedProtocol,
        balance: String,
        fee: String,
        accountName: String,
        locale: Locale?
    )
}

extension ProxyErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentFeeTooHigh(
        from view: ControllerBackedProtocol,
        balance: String,
        fee: String,
        accountName _: String,
        locale: Locale?
    ) {
        let message = R.string.localizable.commonNotEnoughFeeMessage_v380(
            fee,
            balance,
            preferredLanguages: locale?.rLanguages
        )

        let title = R.string.localizable.commonNotEnoughFeeTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
