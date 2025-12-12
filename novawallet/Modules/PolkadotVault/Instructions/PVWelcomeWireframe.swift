import Foundation

final class PVWelcomeWireframe: PVWelcomeWireframeProtocol {
    func showScanQR(
        from view: PVWelcomeViewProtocol?,
        type: ParitySignerType
    ) {
        guard let scanView = PVScanViewFactory.createOnboardingView(with: type) else {
            return
        }

        view?.controller.navigationController?.pushViewController(scanView.controller, animated: true)
    }
}
