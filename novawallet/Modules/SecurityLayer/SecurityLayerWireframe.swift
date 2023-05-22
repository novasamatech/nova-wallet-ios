import UIKit

final class SecurityLayerWireframe: SecurityLayerWireframeProtocol, AuthorizationPresentable, SecuredPresentable {
    var logger: LoggerProtocol?

    weak var authorizationCompletionHandler: SecurityLayerExecutionProtocol?

    private var isPincodeVisible: Bool {
        let rootViewController = UIApplication.shared.keyWindow?.rootViewController
        let presentedController = rootViewController?.topModalViewController

        return rootViewController as? PinSetupViewProtocol != nil || presentedController as? PinSetupViewProtocol != nil
    }

    func showSecuringOverlay() {
        guard !isPincodeVisible else {
            return
        }

        securePresentingView(animated: true)
    }

    func hideSecuringOverlay() {
        unsecurePresentingView()
    }

    func showAuthorization() {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }

        if window.rootViewController as? PinSetupViewProtocol != nil {
            return
        }

        if window.rootViewController as? MainTabBarViewProtocol != nil {
            guard !isAuthorizing else {
                return
            }

            presentModalAuthorization()
        } else {
            presentRootAuthorization(on: window)
        }
    }

    private func presentModalAuthorization() {
        authorize(animated: false) { [weak self] isAuthorized in
            if !isAuthorized {
                self?.logger?.error("Authorization unexpectedly failed")
            }

            self?.authorizationCompletionHandler?.executeScheduledRequests(isAuthorized)
        }
    }

    private func presentRootAuthorization(on window: UIWindow) {
        guard let localAuthentication = PinViewFactory.createSecuredPinView() else {
            return
        }

        window.rootViewController = localAuthentication.controller
    }
}
