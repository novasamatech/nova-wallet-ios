import Foundation

final class DAppFavoritesWireframe: DAppFavoritesWireframeProtocol {
    func close(from view: (any ControllerBackedProtocol)?) {
        view?.controller.dismiss(animated: true)
    }
}
