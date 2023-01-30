import UIKit

final class RootWireframe: RootWireframeProtocol {
    let inAppUpdatesServiceFactory: InAppUpdatesServiceFactoryProtocol?

    init(inAppUpdatesServiceFactory: InAppUpdatesServiceFactoryProtocol? = nil) {
        self.inAppUpdatesServiceFactory = inAppUpdatesServiceFactory
    }

    func showOnboarding(on view: UIWindow) {
        let onboardingView = OnboardingMainViewFactory.createViewForOnboarding()
        let onboardingController = onboardingView?.controller ?? UIViewController()
        let navigationController: UINavigationController

        if let inAppUpdatesService = inAppUpdatesServiceFactory?.createService() {
            navigationController = OnBoardingNavigationController(inAppUpdatesService: inAppUpdatesService)
        } else {
            navigationController = FearlessNavigationController()
        }

        navigationController.viewControllers = [onboardingController]

        view.rootViewController = navigationController
    }

    func showLocalAuthentication(on view: UIWindow) {
        let pincodeView = PinViewFactory.createSecuredPinView()
        let pincodeController = pincodeView?.controller ?? UIViewController()

        view.rootViewController = pincodeController
    }

    func showPincodeSetup(on view: UIWindow) {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }

        view.rootViewController = controller
    }

    func showBroken(on view: UIWindow) {
        // normally user must not see this but on malicious devices it is possible
        view.backgroundColor = .red
    }
}

final class OnBoardingNavigationController: FearlessNavigationController {
    let inAppUpdatesService: SyncServiceProtocol

    init(inAppUpdatesService: SyncServiceProtocol) {
        self.inAppUpdatesService = inAppUpdatesService
        self.inAppUpdatesService.setup()

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        inAppUpdatesService.syncUp()
    }
}
