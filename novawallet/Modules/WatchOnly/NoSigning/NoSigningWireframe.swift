import Foundation

final class NoSigningWireframe: NoSigningWireframeProtocol {
    let completionCallback: () -> Void

    init(completionCallback: @escaping () -> Void) {
        self.completionCallback = completionCallback
    }

    func complete(on view: NoSigningViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completionCallback)
    }
}
