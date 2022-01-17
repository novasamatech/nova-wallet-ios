import Foundation

final class DAppSearchWireframe: DAppSearchWireframeProtocol {
    func close(from view: DAppSearchViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
