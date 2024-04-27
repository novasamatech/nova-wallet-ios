import Foundation

final class CloudBackupCreateWireframe: CloudBackupCreateWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from _: CloudBackupCreateViewProtocol?) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }

    func showPasswordHint(from view: CloudBackupCreateViewProtocol?) {
        guard let hintView = CloudBackupMessageSheetViewFactory.createBackupMessageSheet() else {
            return
        }

        view?.controller.present(hintView.controller, animated: true)
    }
}
