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
        gradientView.motionEffects.forEach { effect in
            gradientView.removeMotionEffect(effect)
        }

        guard let model = model else {
            return
        }

        let xTilt = UIInterpolatingMotionEffect(
            keyPath: "layer.transform",
            type: .tiltAlongHorizontalAxis
        )

        let minOffset = model.slidingMin * bounds.width
        let maxOffset = model.slidingMax * bounds.width

        let minTranslation = CATransform3DMakeTranslation(minOffset, 0, 0)
        let maxTranslation = CATransform3DMakeTranslation(maxOffset, 0, 0)

        xTilt.minimumRelativeValue = minTranslation

        xTilt.maximumRelativeValue = maxTranslation

        gradientView.addMotionEffect(xTilt)
    }
}
