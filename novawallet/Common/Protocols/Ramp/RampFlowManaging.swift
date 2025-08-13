import Foundation

protocol RampFlowManaging {
    func startRampFlow(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        wireframe: (RampPresentable & AlertPresentable)?,
        chainAsset: ChainAsset,
        delegate: RampDelegate,
        locale: Locale
    )
}

extension RampFlowManaging {
    func startRampFlow(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        wireframe: (RampPresentable & AlertPresentable)?,
        chainAsset: ChainAsset,
        delegate: RampDelegate,
        locale: Locale
    ) {
        let rampActions = actions.filter { $0.type == rampType }

        guard !rampActions.isEmpty else {
            return
        }
        if rampActions.count == 1 {
            startFlow(
                view: view,
                action: rampActions[0],
                chainAsset: chainAsset,
                wireframe: wireframe,
                locale: locale,
                delegate: delegate
            )
        } else {
            wireframe?.showRampProviders(
                from: view,
                actions: rampActions,
                rampType: rampType,
                chainAsset: chainAsset,
                delegate: delegate
            )
        }
    }
}

extension RampFlowManaging where Self: RampDelegate {
    func startRampFlow(
        from view: ControllerBackedProtocol?,
        actions: [RampAction],
        rampType: RampActionType,
        wireframe: (RampPresentable & AlertPresentable)?,
        chainAsset: ChainAsset,
        locale: Locale
    ) {
        startRampFlow(
            from: view,
            actions: actions,
            rampType: rampType,
            wireframe: wireframe,
            chainAsset: chainAsset,
            delegate: self,
            locale: locale
        )
    }
}

private extension RampFlowManaging {
    func startFlow(
        view: ControllerBackedProtocol?,
        action: RampAction,
        chainAsset: ChainAsset,
        wireframe: (RampPresentable & AlertPresentable)?,
        locale: Locale,
        delegate: RampDelegate
    ) {
        let title = R.string.localizable.commonAlertExternalLinkDisclaimerTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.commonAlertExternalLinkDisclaimerMessage(
            action.displayURLString,
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
                chainAsset: chainAsset,
                delegate: delegate
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
