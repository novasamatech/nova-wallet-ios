import UIKit

extension TriangularedBlurView {
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
    private var _blurStyle: Int {
        get {
            blurStyle.rawValue
        }

        set {
            if let newBlur = UIBlurEffect.Style(rawValue: newValue) {
                blurStyle = newBlur
            }
        }
    }

    @IBInspectable
    private var _overlayFillColor: UIColor {
        get {
            overlayView.fillColor
        }

        set {
            overlayView.fillColor = newValue
            overlayView.highlightedFillColor = newValue
        }
    }
}
