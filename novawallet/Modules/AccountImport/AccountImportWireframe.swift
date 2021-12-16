import Foundation
import IrohaCrypto

final class AccountImportWireframe: BaseAccountImportWireframe, AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from _: AccountImportViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }
}
