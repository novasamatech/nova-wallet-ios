import Foundation

final class ParitySignerWelcomeWireframe: ParitySignerWelcomeWireframeProtocol {
    func showScanQR(from view: ParitySignerWelcomeViewProtocol?, type: ParitySignerType) {
        guard let scanView = ParitySignerScanViewFactory.createOnboardingView(with: type) else {
            return
        }

        view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
    }
}
