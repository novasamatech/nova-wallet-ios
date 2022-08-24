import Foundation

final class MessageSheetWireframe: MessageSheetWireframeProtocol {
    let completionCallback: MessageSheetCallback?

    init(completionCallback: MessageSheetCallback?) {
        self.completionCallback = completionCallback
    }

    func complete(on view: MessageSheetViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: completionCallback)
    }
}
