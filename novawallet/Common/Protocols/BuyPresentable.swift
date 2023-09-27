protocol BuyPresentable {
    func buyTokens(
        from view: ControllerBackedProtocol?,
        purchaseActions: [PurchaseAction],
        wireframe: PurchasePresentable?
    )
}

extension BuyPresentable where Self: ModalPickerViewControllerDelegate & PurchaseDelegate {
    func buyTokens(
        from view: ControllerBackedProtocol?,
        purchaseActions: [PurchaseAction],
        wireframe: PurchasePresentable?
    ) {
        guard !purchaseActions.isEmpty else {
            return
        }
        if purchaseActions.count == 1 {
            wireframe?.showPurchaseTokens(
                from: view,
                action: purchaseActions[0],
                delegate: self
            )
        } else {
            wireframe?.showPurchaseProviders(
                from: view,
                actions: purchaseActions,
                delegate: self
            )
        }
    }
}
