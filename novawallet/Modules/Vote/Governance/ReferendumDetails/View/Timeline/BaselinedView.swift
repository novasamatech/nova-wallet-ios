import UIKit

protocol BaselinedView: UIView {
    var firstBaseline: UIView { get }
}

extension GenericMultiValueView: BaselinedView {
    var firstBaseline: UIView {
        valueTop
    }
}

extension UILabel: BaselinedView {
    var firstBaseline: UIView {
        self
    }
}
