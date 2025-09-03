import Foundation

protocol TokenAddErrorPresentable: BaseErrorPresentable {
    func presentInvalidContractAddress(
        from view: ControllerBackedProtocol,
        locale: Locale?
    )

    func presentInvalidNetworkContract(
        from view: ControllerBackedProtocol,
        name: String,
        locale: Locale?
    )

    func presentInvalidDecimals(
        from view: ControllerBackedProtocol,
        maxValue: String,
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

    func presentTokenUpdate(
        from view: ControllerBackedProtocol,
        symbol: String,
        onContinue: @escaping () -> Void,
        locale: Locale?
    )
}

extension TokenAddErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentInvalidContractAddress(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidContractAddressMessage()
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidContractAddressTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentInvalidNetworkContract(
        from view: ControllerBackedProtocol,
        name: String,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidNetworkContractMessage(
            name
        )
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidContractAddressTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentInvalidDecimals(
        from view: ControllerBackedProtocol,
        maxValue: String,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidDecimalsMessage(
            maxValue
        )
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidDecimalsTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentTokenAlreadyExists(
        from view: ControllerBackedProtocol,
        symbol: String,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenAlreadyExistsMessage(symbol)
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenAlreadyExistsTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentInvalidCoingeckoPriceUrl(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidPriceUrlMessage()
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenInvalidPriceUrlTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentTokenUpdate(
        from view: ControllerBackedProtocol,
        symbol: String,
        onContinue: @escaping () -> Void,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.addTokenAlreadyExistsTitle()
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.tokenAddRemoteExistMessage(symbol)

        let continueAction = AlertPresentableAction(
            title: R.string(preferredLanguages: locale.rLanguages).localizable.commonContinue(),
            style: .destructive
        ) {
            onContinue()
        }

        let viewModel = AlertPresentableViewModel(
            title: title,
            message: message,
            actions: [continueAction],
            closeAction: R.string(preferredLanguages: locale.rLanguages).localizable.commonCancel()
        )

        present(viewModel: viewModel, style: .alert, from: view)
    }
}
