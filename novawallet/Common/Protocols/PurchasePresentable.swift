import Foundation

protocol RampPresentable {
    func showRampAction(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        delegate: RampDelegate
    )

    func showOnRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        assetSymbol: AssetModel.Symbol,
        delegate: RampDelegate
    )

    func showOffRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        assetSymbol: AssetModel.Symbol,
        delegate: RampDelegate
    )

    func presentOnRampDidComplete(
        view: ControllerBackedProtocol?,
        locale: Locale
    )

    func presentOffRampDidComplete(
        view: ControllerBackedProtocol?,
        locale: Locale
    )
}

extension RampPresentable {
    func showRampAction(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        delegate: RampDelegate
    ) {
        guard let purchaseView = RampViewFactory.createView(
            for: action,
            delegate: delegate
        ) else {
            return
        }
        purchaseView.controller.modalPresentationStyle = .fullScreen
        view?.controller.present(purchaseView.controller, animated: true)
    }

    func showOnRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        assetSymbol: AssetModel.Symbol,
        delegate: RampDelegate
    ) {
        guard let onRampProvidersView = SelectRampProviderViewFactory.createView(
            providerType: .onramp,
            rampActions: actions,
            assetSymbol: assetSymbol,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            onRampProvidersView.controller,
            animated: true
        )
    }

    func showOffRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        assetSymbol: AssetModel.Symbol,
        delegate: RampDelegate
    ) {
        guard let offRampProvidersView = SelectRampProviderViewFactory.createView(
            providerType: .offramp,
            rampActions: actions,
            assetSymbol: assetSymbol,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            offRampProvidersView.controller,
            animated: true
        )
    }

    func presentOnRampDidComplete(
        view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let languages = locale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)

        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }

    func presentOffRampDidComplete(
        view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let languages = locale.rLanguages
        let message = R.string.localizable
            .sellCompleted(preferredLanguages: languages)

        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }
}
