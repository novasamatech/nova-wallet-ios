import Foundation

protocol AddressScanPresentable {
    func showAddressScan(
        from view: ControllerBackedProtocol?,
        delegate: AddressScanDelegate,
        context: AnyObject?
    )

    func hideAddressScan(from view: ControllerBackedProtocol?)
}

extension AddressScanPresentable {
    func showAddressScan(
        from view: ControllerBackedProtocol?,
        delegate: AddressScanDelegate,
        context: AnyObject?
    ) {
        guard
            let scanView = AddressScanViewFactory.createAnyAddressScan(
                for: delegate,
                context: context
            ) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: scanView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func hideAddressScan(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
