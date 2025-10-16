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

    func presentFeeTooHigh(
        from view: ControllerBackedProtocol,
        balance: String,
        fee: String,
        accountName: String,
        locale: Locale?
    )

    func presentSelfDelegating(
        from view: ControllerBackedProtocol,
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
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorInsufficientBalanceTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorInsufficientBalanceMessage(
            deposit,
            balance
        )
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentMaximumProxyCount(
        from view: ControllerBackedProtocol?,
        limit: String,
        networkName: String,
        locale: Locale
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorInvalidMaximumProxiesTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorInvalidMaximumProxiesMessage(
            limit,
            networkName
        )
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentProxyAlreadyAdded(
        from view: ControllerBackedProtocol?,
        account: String,
        locale: Locale
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorProxyAlreadyExistsTitle()

        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorProxyAlreadyExistsMessage(
            account
        )
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentNotValidAddress(
        from view: ControllerBackedProtocol,
        networkName: String,
        locale: Locale?
    ) {
        let title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorInvalidAddressTitle()
        let message = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.stakingSetupProxyErrorInvalidAddressMessage(
            networkName
        )
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentFeeTooHigh(
        from view: ControllerBackedProtocol,
        balance: String,
        fee: String,
        accountName: String,
        locale: Locale?
    ) {
        let message = R.string(preferredLanguages: locale.rLanguages).localizable.proxyFeeErrorMessage(
            accountName,
            fee,
            balance
        )

        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonNotEnoughFeeTitle()
        let closeAction = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: closeAction, from: view)
    }

    func presentSelfDelegating(
        from view: ControllerBackedProtocol,
        locale: Locale?
    ) {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.govAddDelegateSelfErrorTitle()

        let message = R.string(preferredLanguages: locale.rLanguages).localizable.govAddDelegateSelfErrorMessage()

        let close = R.string(preferredLanguages: locale.rLanguages).localizable.commonClose()

        present(message: message, title: title, closeAction: close, from: view)
    }
}
