import Foundation

class BaseCreateWatchOnlyWireframe: BaseCreateWatchOnlyWireframeProtocol {
    func showAddressScan(
        from view: CreateWatchOnlyViewProtocol?,
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
}
