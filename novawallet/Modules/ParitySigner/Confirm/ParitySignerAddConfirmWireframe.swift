import Foundation

final class ParitySignerAddConfirmWireframe: ParitySignerAddConfirmWireframeProtocol {
    func complete(on _: ControllerBackedProtocol?) {
        lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

        func proceed(from _: CreateWatchOnlyViewProtocol?) {
            guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
                return
            }

            rootAnimator.animateTransition(to: pincodeViewController)
        }
    }
}
