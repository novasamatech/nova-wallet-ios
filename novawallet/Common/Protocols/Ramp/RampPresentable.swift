import Foundation

protocol RampPresentable {
    func showRampAction(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        chainAsset: ChainAsset,
        delegate: RampDelegate
    )

    func showRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        chainAsset: ChainAsset,
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
        chainAsset: ChainAsset,
        delegate: RampDelegate
    ) {
        guard let rampView = RampViewFactory.createView(
            for: action,
            chainAsset: chainAsset,
            delegate: delegate
        ) else {
            return
        }

        if view?.controller.presentingViewController != nil {
            view?.controller.navigationController?.pushViewController(
                rampView.controller,
                animated: true
            )
        } else {
            view?.controller.presentWithCardLayout(
                rampView.controller,
                animated: true
            )
        }
    }

    func showRampProviders(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        chainAsset: ChainAsset,
        delegate: RampDelegate
    ) {
        guard let rampProvidersView = SelectRampProviderViewFactory.createView(
            providerType: rampType,
            rampActions: actions,
            chainAsset: chainAsset,
            delegate: delegate
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: rampProvidersView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
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
