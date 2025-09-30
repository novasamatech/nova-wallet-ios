import Foundation

final class AHMInfoWireframe: AHMInfoWireframeProtocol {
    func complete(from view: AHMInfoViewProtocol?) {
        view?.controller.dismiss(
            animated: true,
            completion: nil
        )
    }
}
