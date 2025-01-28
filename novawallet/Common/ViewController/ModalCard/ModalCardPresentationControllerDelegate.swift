import UIKit

public protocol ModalCardPresentationControllerDelegate: AnyObject {
    func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool
    func presentationControllerDidAttemptToDismiss(_: UIPresentationController)
}

extension ModalCardPresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {}
}
