import UIKit

final class GladingPatternView: UIView {
    let gradientView: MultigradientView = .create { view in
        view.gradientType = .radial
    }

    private var calculatedBounds: CGSize = .zero
    private var model: GladingPatternModel?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if calculatedBounds != bounds.size {
            applyOnBoundsChange()
        }
    }

    func bind(model: GladingPatternModel) {
        self.model = model

        gradientView.colors = model.gradient.colors
        gradientView.startPoint = model.gradient.startPoint
        gradientView.endPoint = model.gradient.endPoint

        applyMask()
        applyMotion()

        setNeedsLayout()
    }

    func setupStyle() {
        backgroundColor = .clear
    }

    func setupLayout() {
        addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 963, height: 246))
        }
    }

    private func applyOnBoundsChange() {
        calculatedBounds = bounds.size

        applyMask()
        applyMotion()
    }

    private func applyMask() {
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

    private func applyMotion() {
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

        xTilt.minimumRelativeValue = CATransform3DRotate(maxTranslation, model.rotation, 0, 0, 1)
        xTilt.maximumRelativeValue = CATransform3DRotate(minTranslation, model.rotation, 0, 0, 1)

        gradientView.addMotionEffect(xTilt)
    }
}
