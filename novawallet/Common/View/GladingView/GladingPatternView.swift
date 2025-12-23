import UIKit

final class GladingPatternView: GladingBaseView {
    private var model: GladingPatternModel?
    private var effect: UIMotionEffect?

    func bind(model: GladingPatternModel) {
        self.model = model

        gradientView.gradientType = .radial
        gradientView.colors = model.gradient.colors
        gradientView.startPoint = model.gradient.startPoint
        gradientView.endPoint = model.gradient.endPoint
        gradientView.locations = model.gradient.locations
        gradientView.alpha = model.opacity

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
        mask.contentsGravity = model.maskContentsGravity
        mask.contentsScale = model.pattern.scale

        layer.mask = mask
    }

    override func applyMotion() {
        gradientContentView.removeEffectIfNeeded(effect)

        guard let model = model else {
            return
        }

        let minX = model.slidingX.min * bounds.width
        let maxX = model.slidingX.max * bounds.width

        let minY = model.slidingY.min * bounds.height
        let maxY = model.slidingY.max * bounds.height

        effect = gradientContentView.addMotion(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }
}
