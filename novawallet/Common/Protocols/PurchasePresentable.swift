import Foundation

protocol RampPresentable {
    func showRampAction(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        delegate: RampDelegate
    )

    func showPurchaseProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        assetSymbol: AssetModel.Symbol,
        delegate: ModalPickerViewControllerDelegate
    )

    func presentPurchaseDidComplete(
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

    func showPurchaseProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        assetSymbol: AssetModel.Symbol,
        delegate _: ModalPickerViewControllerDelegate
    ) {
        guard let purchaseProvidersView = SelectRampProviderViewFactory.createView(
            providerType: .onramp,
            rampActions: actions,
            assetSymbol: assetSymbol
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            purchaseProvidersView.controller,
            animated: true
        )
    }

    func presentPurchaseDidComplete(
        view: ControllerBackedProtocol?,
        locale: Locale
    ) {
        let languages = locale.rLanguages
        let message = R.string.localizable
            .buyCompleted(preferredLanguages: languages)

        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }
}
