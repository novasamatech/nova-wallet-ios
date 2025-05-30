import UIKit

class PinSetupWireframe: PinSetupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()
    let initialFlowStatusPresentingClosure: FlowStatusPresentingClosure?

    init(initialFlowStatusPresentingClosure: FlowStatusPresentingClosure? = nil) {
        self.initialFlowStatusPresentingClosure = initialFlowStatusPresentingClosure
    }

    func showMain(from _: PinSetupViewProtocol?) {
        guard
            let tabBarController = MainTabBarViewFactory.createView()?.controller as? MainTabBarViewController,
            let widgetViewController = DAppBrowserWidgetViewFactory.createView()?.controller as? DAppBrowserWidgetViewController,
            let container = NovaMainAppContainerViewFactory.createView(
                tabBarController: tabBarController,
                browserWidgetController: widgetViewController
            )?.controller
        else {
            return
        }

        rootAnimator.animateTransition(to: container)

        if let initialFlowStatusPresentingClosure {
            tabBarController.presentStatusAlert(initialFlowStatusPresentingClosure)
        }
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createViewForOnboarding()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
