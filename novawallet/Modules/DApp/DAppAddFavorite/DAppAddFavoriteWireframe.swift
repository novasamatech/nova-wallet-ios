import Foundation

final class DAppAddFavoriteWireframe: DAppAddFavoriteWireframeProtocol {
    func close(view: DAppAddFavoriteViewProtocol?) {
        view?.controller.dismiss(animated: true, completion: nil)
    }
}
