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

        xTilt.minimumRelativeValue = CATransform3DRotate(
            maxTranslation,
            model.gradientRotation,
            0,
            0,
            1
        )

        xTilt.maximumRelativeValue = CATransform3DRotate(
            minTranslation,
            model.gradientRotation,
            0,
            0,
            1
        )

        gradientView.addMotionEffect(xTilt)
    }
}
