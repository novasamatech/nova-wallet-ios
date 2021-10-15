import Foundation
import SoraUI

/// Extension of the TriangularedView to support design through Interface Builder
extension TriangularedView {
    @IBInspectable
    private var _cornerCut: UInt {
        get {
            cornerCut.rawValue
        }

        set {
            cornerCut = UIRectCorner(rawValue: newValue)
        }
    }
}
