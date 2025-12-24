import Foundation
import NovaCrypto

final class AccountImportWireframe: BaseAccountImportWireframe, AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from _: AccountImportViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }

    func presentScanner(
        from view: AccountImportViewProtocol?,
        importDelegate: SecretScanImportDelegate
    ) {
        let scanView = SecretScanViewFactory.createView(importDelegate: importDelegate)

        view?.controller.navigationController?.pushViewController(
            scanView.controller,
            animated: true
        )
    }
}
