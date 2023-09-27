protocol PurchasePresentable {
    func showPurchaseTokens(
        from view: ControllerBackedProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    )

    func showPurchaseProviders(
        from view: ControllerBackedProtocol?,
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    )
}

extension PurchasePresentable where Self: AlertPresentable {
    func showPurchaseTokens(
        from view: ControllerBackedProtocol?,
        action: PurchaseAction,
        delegate: PurchaseDelegate
    ) {
        guard let purchaseView = PurchaseViewFactory.createView(
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
        actions: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    ) {
        guard let pickerView = ModalPickerFactory.createPickerForList(
            actions,
            delegate: delegate,
            context: nil
        ) else {
            return
        }
        guard let navigationController = view?.controller.navigationController else {
            return
        }
        navigationController.present(pickerView, animated: true)
    }
}
