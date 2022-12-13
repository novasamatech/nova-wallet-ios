import Foundation

protocol TokenAddErrorPresentable: BaseErrorPresentable {
    func presentInvalidContractAddress(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentTokenAlreadyExists(
        from view: ControllerBackedProtocol,
        symbol: String,
        locale: Locale?
    )

    func presentInvalidCoingeckoPriceUrl(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )
}

extension TokenAddErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentInvalidContractAddress(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let message = R.string.localizable.addTokenInvalidContractAddressMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.addTokenInvalidContractAddressTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentTokenAlreadyExists(
        from view: ControllerBackedProtocol,
        symbol: String,
        locale: Locale?
    ) {
        let message = R.string.localizable.addTokenAlreadyExistsMessage(symbol, preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.addTokenAlreadyExistsTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentInvalidCoingeckoPriceUrl(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let message = R.string.localizable.addTokenInvalidPriceUrlMessage(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.addTokenInvalidPriceUrlTitle(preferredLanguages: locale?.rLanguages)
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}
