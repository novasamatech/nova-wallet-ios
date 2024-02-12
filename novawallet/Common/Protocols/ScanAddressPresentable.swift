protocol ScanAddressPresentable {
    func showAddressScan(
        from view: ControllerBackedProtocol?,
        delegate: AddressScanDelegate
    )
    func hideAddressScan(from view: ControllerBackedProtocol?)
}

extension ScanAddressPresentable {
    func showAddressScan(
        from view: ControllerBackedProtocol?,
        delegate: AddressScanDelegate
    ) {
        guard
            let scanView = AddressScanViewFactory.createTransferRecipientScan(
                for: delegate,
                context: nil
            ) else {
            return
        }

        let navigationController = NovaNavigationController(
            rootViewController: scanView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func hideAddressScan(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
