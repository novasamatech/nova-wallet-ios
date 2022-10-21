import UIKit

extension UIView {
    func frame(in targetView: UIView) -> CGRect {
        var view = self
        var rect = view.frame

        while let superview = view.superview {
            if superview == targetView {
                return rect
            }
            rect = view.convert(rect, to: superview)
            view = superview
        }

        return rect
    }
}
