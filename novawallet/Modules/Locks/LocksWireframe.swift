import Foundation

final class LocksWireframe: LocksWireframeProtocol {
    func close(view: LocksViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
