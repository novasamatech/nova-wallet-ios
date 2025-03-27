import Foundation

protocol RampPresentable {
    func showRampAction(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        delegate: RampDelegate
    )

    func showRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        assetSymbol: AssetModel.Symbol,
        delegate: RampDelegate
    )

    func presentRampDidComplete(
        view: ControllerBackedProtocol?,
        action: RampActionType,
        locale: Locale
    )
}

extension RampPresentable {
    func showRampAction(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        delegate: RampDelegate
    ) {
        guard let rampView = RampViewFactory.createView(
            for: action,
            delegate: delegate
        ) else {
            return
        }
        rampView.controller.modalPresentationStyle = .fullScreen
        view?.controller.present(rampView.controller, animated: true)
    }

    func showRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        assetSymbol: AssetModel.Symbol,
        delegate: RampDelegate
    ) {
        guard let rampProvidersView = SelectRampProviderViewFactory.createView(
            providerType: rampType,
            rampActions: actions,
            assetSymbol: assetSymbol,
            delegate: delegate
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            rampProvidersView.controller,
            animated: true
        )
    }

    func presentRampDidComplete(
        view: ControllerBackedProtocol?,
        action: RampActionType,
        locale: Locale
    ) {
        let languages = locale.rLanguages

        let message = switch action {
        case .onRamp:
            R.string.localizable.buyCompleted(preferredLanguages: languages)
        case .offRamp:
            R.string.localizable.sellCompleted(preferredLanguages: languages)
        }

        let alertController = ModalAlertFactory.createMultilineSuccessAlert(message)
        view?.controller.present(alertController, animated: true)
    }
}
