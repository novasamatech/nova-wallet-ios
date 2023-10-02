import SoraFoundation

protocol PurchaseFlowManaging {
    func startPuchaseFlow(
        from view: ControllerBackedProtocol?,
        purchaseActions: [PurchaseAction],
        wireframe: (PurchasePresentable & AlertPresentable)?,
        locale: Locale
    )
}

extension PurchaseFlowManaging where Self: ModalPickerViewControllerDelegate & PurchaseDelegate {
    func startPuchaseFlow(
        from view: ControllerBackedProtocol?,
        purchaseActions: [PurchaseAction],
        wireframe: (PurchasePresentable & AlertPresentable)?,
        locale: Locale
    ) {
        guard !purchaseActions.isEmpty else {
            return
        }
        if purchaseActions.count == 1 {
            startPuchaseFlow(from: view, purchaseAction: purchaseActions[0], wireframe: wireframe, locale: locale)
        } else {
            wireframe?.showPurchaseProviders(
                from: view,
                actions: purchaseActions,
                delegate: self
            )
        }
    }

    func startPuchaseFlow(
        from view: ControllerBackedProtocol?,
        purchaseAction: PurchaseAction,
        wireframe: (PurchasePresentable & AlertPresentable)?,
        locale: Locale
    ) {
        let title = R.string.localizable.commonAlertExternalLinkDisclaimerTitle(preferredLanguages: locale.rLanguages)
        let message = R.string.localizable.commonAlertExternalLinkDisclaimerMessage(
            purchaseAction.displayURL,
            preferredLanguages: locale.rLanguages
        )

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let continueTitle = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
        let continueAction = AlertPresentableAction(title: continueTitle) {
            wireframe?.showPurchaseTokens(
                from: view,
                action: purchaseAction,
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
