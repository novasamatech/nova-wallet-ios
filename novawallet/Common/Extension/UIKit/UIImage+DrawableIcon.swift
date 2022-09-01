import UIKit
import SubstrateSdk

extension UIImage: DrawableIcon {
    public func drawInContext(_: CGContext, fillColor _: UIColor, size: CGSize) {
        draw(in: .init(origin: .zero, size: size))
    }
}
