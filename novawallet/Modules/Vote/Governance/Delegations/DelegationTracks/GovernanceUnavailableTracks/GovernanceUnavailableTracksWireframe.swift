import Foundation

final class GovernanceUnavailableTracksWireframe: GovernanceUnavailableTracksWireframeProtocol {
    func complete(on view: ControllerBackedProtocol?, completionHandler: @escaping () -> Void) {
        view?.controller.presentingViewController?.dismiss(
            animated: true,
            completion: completionHandler
        )
    }
}
