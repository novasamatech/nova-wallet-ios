import UIKit

class PinSetupWireframe: PinSetupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showMain(from _: PinSetupViewProtocol?) {
        guard
            let tabBarController = MainTabBarViewFactory.createView()?.controller,
            let widgetViewController = DAppBrowserWidgetViewFactory.createView(),
            let container = NovaMainAppContainerViewFactory.createView(
                tabBarController: tabBarController,
                browserWidgetController: widgetViewController
            )?.controller
        else {
            return
        }

        rootAnimator.animateTransition(to: container)
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createViewForOnboarding()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
