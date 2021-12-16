import UIKit
import SoraUI

/**
    Subclass of ShadowShapeView designed to provided view with rounded corners.
 */

open class TriangularedView: ShadowShapeView {
    /// Side of the triangle that cuts the corners. Defaults `10.0`
    @IBInspectable
    open var sideLength: CGFloat = 10.0 {
        didSet {
            applyPath()
        }
    }

    /// Controls which corners should be cut. By default all.
    open var cornerCut: UIRectCorner = .allCorners {
        didSet {
            applyPath()
        }
    }

    // MARK: Overriden methods

    override open var shapePath: UIBezierPath {
        let layerBounds: CGRect = bounds

        let bezierPath = UIBezierPath(
            roundedRect: layerBounds,
            byRoundingCorners: cornerCut,
            cornerRadii: CGSize(width: sideLength, height: sideLength)
        )

        return bezierPath
    }
}
