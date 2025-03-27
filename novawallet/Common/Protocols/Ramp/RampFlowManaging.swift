import Foundation

protocol RampFlowManaging {
    func startRampFlow(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        wireframe: (RampPresentable & AlertPresentable)?,
        assetSymbol: AssetModel.Symbol,
        locale: Locale
    )
}

extension RampFlowManaging where Self: RampDelegate {
    func startRampFlow(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        wireframe: (RampPresentable & AlertPresentable)?,
        assetSymbol: AssetModel.Symbol,
        locale: Locale
    ) {
        let rampActions = actions.filter { $0.type == rampType }

        guard !rampActions.isEmpty else {
            return
        }
        if rampActions.count == 1 {
            startFlow(
                from: view,
                action: rampActions[0],
                wireframe: wireframe,
                locale: locale
            )
        } else {
            wireframe?.showRampProviders(
                from: view,
                actions: rampActions,
                rampType: rampType,
                assetSymbol: assetSymbol,
                delegate: self
            )
        }
    }
}

private extension RampFlowManaging where Self: RampDelegate {
    func startFlow(
        from view: ControllerBackedProtocol?,
        action: RampAction,
        wireframe: (RampPresentable & AlertPresentable)?,
        locale: Locale
    ) {
        let title = R.string.localizable.commonAlertExternalLinkDisclaimerTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.commonAlertExternalLinkDisclaimerMessage(
            action.url.absoluteString,
            preferredLanguages: locale.rLanguages
        )

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let continueTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        let continueAction = AlertPresentableAction(title: continueTitle) {
            wireframe?.showRampAction(
                from: view,
                action: action,
                delegate: self
            )
        }

        wireframe?.present(
            viewModel: .init(
                title: title,
                message: message,
                actions: [continueAction],
                closeAction: closeTitle
            ),
            style: .alert,
            from: view
        )
    }
}
