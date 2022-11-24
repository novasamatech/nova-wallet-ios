import UIKit

extension UIView {
    static func createSeparator(color: UIColor? = R.color.colorDivider()) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        return view
    }
}
