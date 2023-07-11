import UIKit

class GladingRectView: GladingBaseView {
    private var model: GladingRectModel?
    private var effect: UIMotionEffect?

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
