import UIKit

extension UIView {
    func cutHole(
        on view: UIView,
        underView: UIView,
        holeWidth: CGFloat,
        radius: CGFloat? = nil
    ) {
        guard !underView.isHidden else {
            view.layer.mask = nil
            return
        }

        let width = underView.bounds.width + holeWidth * 2
        let height = underView.bounds.height + holeWidth * 2
        let origin = convert(underView.frame.origin, to: view)

        let frame = CGRect(
            x: origin.x - holeWidth,
            y: origin.y - holeWidth,
            width: width,
            height: height
        )

        if let radius = radius {
            view.cutHole(
                roundedRect: frame,
                cornerRadii: CGSize(
                    width: radius + holeWidth / 2,
                    height: radius + holeWidth / 2
                )
            )
        } else {
            view.cutHole(ovalIn: frame)
        }
    }

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

    func removeHole(on view: UIView) {
        view.layer.mask = nil
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
