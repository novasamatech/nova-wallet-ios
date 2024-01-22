import Foundation

protocol ProxyErrorPresentable: BaseErrorPresentable {
    func presentNotEnoughBalanceForDeposit(
        from view: ControllerBackedProtocol,
        deposit: String,
        balance: String,
        locale: Locale?
    )

    func presentMaximumProxyCount(
        from view: ControllerBackedProtocol?,
        limit: String,
        networkName: String,
        locale: Locale
    )

    func presentProxyAlreadyAdded(
        from view: ControllerBackedProtocol?,
        account: String,
        locale: Locale
    )

    func presentNotValidAddress(
        from view: ControllerBackedProtocol,
        networkName: String,
        locale: Locale?
    )
}

extension ProxyErrorPresentable where Self: AlertPresentable & ErrorPresentable {
    func presentNotEnoughBalanceForDeposit(
        from view: ControllerBackedProtocol,
        deposit: String,
        balance: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.stakingSetupProxyErrorInsufficientBalanceTitle(
            preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.stakingSetupProxyErrorInsufficientBalanceMessage(
            deposit,
            balance,
            preferredLanguages: locale?.rLanguages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMaximumProxyCount(
        from view: ControllerBackedProtocol?,
        limit: String,
        networkName: String,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingSetupProxyErrorInvalidMaximumProxiesTitle(
            preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingSetupProxyErrorInvalidMaximumProxiesMessage(
            limit,
            networkName,
            preferredLanguages: locale.rLanguages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: locale.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentProxyAlreadyAdded(
        from view: ControllerBackedProtocol?,
        account: String,
        locale: Locale
    ) {
        let title = R.string.localizable.stakingSetupProxyErrorProxyAlreadyExistsTitle(
            preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.stakingSetupProxyErrorProxyAlreadyExistsMessage(
            account,
            preferredLanguages: locale.rLanguages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: locale.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotValidAddress(
        from view: ControllerBackedProtocol,
        networkName: String,
        locale: Locale?
    ) {
        let title = R.string.localizable.stakingSetupProxyErrorInvalidAddressTitle(
            preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable.stakingSetupProxyErrorInvalidAddressMessage(
            networkName,
            preferredLanguages: locale?.rLanguages
        )
        let closeAction = R.string.localizable.commonClose(
            preferredLanguages: locale?.rLanguages)

        present(message: message, title: title, closeAction: closeAction, from: view)
    }
}