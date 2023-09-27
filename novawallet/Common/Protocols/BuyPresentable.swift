import SoraFoundation

protocol BuyPresentable {
    func buyTokens(
        from view: ControllerBackedProtocol?,
        purchaseActions: [PurchaseAction],
        wireframe: (PurchasePresentable & AlertPresentable)?,
        locale: Locale
    )
}

extension BuyPresentable where Self: ModalPickerViewControllerDelegate & PurchaseDelegate {
    func buyTokens(
        from view: ControllerBackedProtocol?,
        purchaseActions: [PurchaseAction],
        wireframe: (PurchasePresentable & AlertPresentable)?,
        locale: Locale
    ) {
        guard !purchaseActions.isEmpty else {
            return
        }
        if purchaseActions.count == 1 {
            buyTokens(from: view, purchaseAction: purchaseActions[0], wireframe: wireframe, locale: locale)
        } else {
            wireframe?.showPurchaseProviders(
                from: view,
                actions: purchaseActions,
                delegate: self
            )
        }
    }

    func buyTokens(
        from view: ControllerBackedProtocol?,
        purchaseAction: PurchaseAction,
        wireframe: (PurchasePresentable & AlertPresentable)?,
        locale: Locale
    ) {
        let title = "You are leaving Nova Wallet"
        let message = "You will be redirected to banxa.com"

        let closeTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let proceedTitle = R.string.localizable
            .commonProceed(preferredLanguages: locale.rLanguages)
        let proceedAction = AlertPresentableAction(title: proceedTitle) {
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
                actions: [proceedAction],
                closeAction: closeTitle
            ),
            style: .alert,
            from: view
        )
    }
}
