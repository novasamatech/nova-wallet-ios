import UIKit

extension UIView {
    func cutHole(roundedRect: CGRect, cornerRadii: CGSize) {
        let entireViewPath = UIBezierPath(rect: bounds)

        let roundedRectPath = UIBezierPath(
            roundedRect: roundedRect,
            byRoundingCorners: .allCorners,
            cornerRadii: cornerRadii
        )
        entireViewPath.append(roundedRectPath)
        entireViewPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = entireViewPath.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        maskLayer.fillColor = UIColor.black.cgColor
        layer.mask = maskLayer
    }
}
