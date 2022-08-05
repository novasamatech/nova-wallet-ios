import Foundation

final class ParitySignerWelcomeWireframe: ParitySignerWelcomeWireframeProtocol {
    func showScanQR(from view: ParitySignerWelcomeViewProtocol?) {
        guard let scanView = ParitySignerScanViewFactory.createOnboardingView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
    }
}
