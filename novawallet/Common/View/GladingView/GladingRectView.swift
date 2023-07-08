import UIKit

class GladingRectView: GladingBaseView {
    private var model: GladingRectModel?

    func bind(model: GladingRectModel) {
        self.model = model

        gradientView.gradientType = .linear
        gradientView.colors = model.gradient.colors
        gradientView.startPoint = model.gradient.startPoint
        gradientView.endPoint = model.gradient.endPoint
        gradientView.locations = model.gradient.locations

        gradientView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(model.gradientSize)
        }

        gradientView.transform = CGAffineTransformMakeRotation(model.rotation)

        applyMask()
        applyMotion()

        setNeedsLayout()
    }

    override func applyMask() {
        guard let model = model else {
            return
        }

        let mask = CAShapeLayer()

        switch model.mode {
        case let .stroke(width):
            mask.strokeColor = UIColor.black.cgColor
            mask.lineWidth = width
            mask.fillColor = UIColor.clear.cgColor
        case .fill:
            mask.strokeColor = UIColor.clear.cgColor
            mask.fillColor = UIColor.black.cgColor
        }

        let rect = CGRect(origin: .zero, size: bounds.size)
        mask.frame = rect
        mask.path = UIBezierPath(roundedRect: rect, cornerRadius: model.cornerRadius).cgPath

        layer.mask = mask
    }

    override func applyMotion() {
        gradientContentView.motionEffects.forEach { effect in
            gradientContentView.removeMotionEffect(effect)
        }

        guard let model = model else {
            return
        }

        let minXOffset = model.slidingX.min * bounds.width
        let maxXOffset = model.slidingX.max * bounds.width

        let minYOffset = model.slidingY.min * bounds.height
        let maxYOffset = model.slidingY.max * bounds.height

        gradientContentView.addMotion(
            minX: minXOffset,
            maxX: maxXOffset,
            minY: minYOffset,
            maxY: maxYOffset
        )
    }
}
