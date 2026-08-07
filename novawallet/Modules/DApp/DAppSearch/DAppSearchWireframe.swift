import Foundation

final class DAppSearchWireframe: DAppSearchWireframeProtocol {
    func close(from view: DAppSearchViewProtocol?, completion: (() -> Void)?) {
        if let presentingController = view?.controller.presentingViewController {
            presentingController.dismiss(animated: true, completion: completion)
        } else {
            completion?()
        }
    }
}
