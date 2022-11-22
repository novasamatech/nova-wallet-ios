import UIKit
import SoraUI

extension ShadowShapeView {
    struct Style {
        let shadowOpacity: Float?
        let shadowColor: UIColor?
        let shadowRadius: CGFloat?
        let shadowOffset: CGSize?
    }

    func apply(style: Style) {
        style.shadowOpacity.map { shadowOpacity = $0 }
        style.shadowColor.map { shadowColor = $0 }
        style.shadowRadius.map { shadowRadius = $0 }
        style.shadowOffset.map { shadowOffset = $0 }
    }
}
