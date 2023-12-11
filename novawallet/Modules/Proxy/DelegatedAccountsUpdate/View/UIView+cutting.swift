import UIKit

extension UIView {
    func cutHole(roundedRect: CGRect, cornerRadii: CGSize) {
        let roundedRectPath = UIBezierPath(
            roundedRect: roundedRect,
            byRoundingCorners: .allCorners,
            cornerRadii: cornerRadii
        )
        cut(path: roundedRectPath)
    }

    func cutHole(ovalIn rect: CGRect) {
        let ovalPath = UIBezierPath(ovalIn: rect)
        cut(path: ovalPath)
    }

    private func cut(path: UIBezierPath) {
        let entireViewPath = UIBezierPath(rect: bounds)
        entireViewPath.append(path)
        entireViewPath.usesEvenOddFillRule = true

        let maskLayer = CAShapeLayer()
        maskLayer.path = entireViewPath.cgPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        maskLayer.fillColor = UIColor.black.cgColor
        layer.mask = maskLayer
    }
}
