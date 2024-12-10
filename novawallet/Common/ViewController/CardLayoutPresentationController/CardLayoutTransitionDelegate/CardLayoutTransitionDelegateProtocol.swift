import UIKit

protocol CardLayoutTransitionDelegateProtocol {
    func didReceivePanState(
        _ state: UIGestureRecognizer.State,
        translation: CGPoint,
        for view: UIView
    )
}
