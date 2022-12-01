import UIKit

extension BlockBackgroundView {
    @IBInspectable
    private var _cornerCut: UInt {
        get {
            cornerCut.rawValue
        }

        set {
            cornerCut = UIRectCorner(rawValue: newValue)
        }
    }

    @IBInspectable
    private var _overlayFillColor: UIColor {
        get {
            overlayView?.fillColor ?? UIColor.black
        }

        set {
            overlayView?.fillColor = newValue
            overlayView?.highlightedFillColor = newValue
        }
    }
}
