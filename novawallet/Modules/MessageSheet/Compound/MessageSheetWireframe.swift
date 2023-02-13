import Foundation

final class MessageSheetWireframe: MessageSheetWireframeProtocol {
    func complete(on view: MessageSheetViewProtocol?, with action: MessageSheetAction?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: action?.handler)
    }
}
