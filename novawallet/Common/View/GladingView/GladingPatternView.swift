import UIKit

final class GladingPatternView: GladingBaseView {
    private var model: GladingPatternModel?

    func bind(model: GladingPatternModel) {
        self.model = model

        gradientView.gradientType = .radial
        gradientView.colors = model.gradient.colors
        gradientView.startPoint = model.gradient.startPoint
        gradientView.endPoint = model.gradient.endPoint
        gradientView.locations = model.gradient.locations

        gradientView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(model.gradientSize)
        }

        gradientView.transform = CGAffineTransformMakeRotation(model.gradientRotation)

        applyMask()
        applyMotion()

        setNeedsLayout()
    }

    override func applyMask() {
        guard let model = model else {
            return
        }

        let mask = CALayer()
        mask.frame = CGRect(origin: .zero, size: bounds.size)
        mask.contents = model.pattern.withRenderingMode(.alwaysTemplate).cgImage
        mask.contentsGravity = .center
        mask.contentsScale = model.pattern.scale

        layer.mask = mask
    }

    override func applyMotion() {
        gradientContentView.motionEffects.forEach { effect in
            gradientContentView.removeMotionEffect(effect)
        }

        guard let model = model else {
            return
        }

        let xTilt = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )

        let minXOffset = model.slidingX.min * bounds.width
        let maxXOffset = model.slidingX.max * bounds.width

        xTilt.minimumRelativeValue = minXOffset
        xTilt.maximumRelativeValue = maxXOffset

        let yTilt = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )

        let minYOffset = model.slidingY.min * bounds.height
        let maxYOffset = model.slidingY.max * bounds.height

        yTilt.minimumRelativeValue = minYOffset
        yTilt.maximumRelativeValue = maxYOffset

        let tilt = UIMotionEffectGroup()
        tilt.motionEffects = [xTilt, yTilt]

        gradientContentView.addMotionEffect(tilt)
    }
}