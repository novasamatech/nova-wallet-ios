import UIKit

extension SubtensorValueTone {
    var textColor: UIColor? {
        switch self {
        case .neutral:
            return R.color.colorTextPrimary()
        case .positive:
            return R.color.colorTextPositive()
        case .negative:
            return R.color.colorTextNegative()
        }
    }
}
