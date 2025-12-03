import Foundation

final class ParitySignerWelcomeWireframe: ParitySignerWelcomeWireframeProtocol {
    func showScanQR(
        from view: ParitySignerWelcomeViewProtocol?,
        type: ParitySignerType,
        mode: ParitySignerWelcomeMode
    ) {
        guard let scanView = ParitySignerScanViewFactory.createOnboardingView(with: type, mode: mode) else {
            return
        }

        view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
    }
}
