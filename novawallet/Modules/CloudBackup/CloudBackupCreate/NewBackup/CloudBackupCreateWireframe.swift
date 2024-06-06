import Foundation

final class CloudBackupCreateWireframe: BaseCloudBackupUpdatePasswordWireframe, CloudBackupCreateWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from _: CloudBackupCreateViewProtocol?, locale _: Locale) {
        guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: pincodeViewController)
    }
}
