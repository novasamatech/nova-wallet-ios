import Foundation

final class MessageSheetWireframe: MessageSheetWireframeProtocol {
    let completionCallback: () -> Void

    init(completionCallback: @escaping () -> Void) {
        self.completionCallback = completionCallback
    }

    func complete(on view: MessageSheetViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completionCallback)
    }
}
