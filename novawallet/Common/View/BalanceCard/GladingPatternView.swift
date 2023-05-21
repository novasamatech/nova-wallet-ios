import UIKit

final class GladingPatternView: UIView {
    let gradientView: MultigradientView = .create { view in
        view.gradientType = .radial
    }

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

        let mask = gradientView.customMask
        mask?.frame = CGRect(origin: .zero, size: bounds.size)
        gradientView.customMask = mask
    }

    func bind(model: GladingPatternModel) {
        gradientView.colors = model.gradient.colors
        gradientView.startPoint = model.gradient.startPoint
        gradientView.endPoint = model.gradient.endPoint

        let mask = CALayer()
        mask.frame = CGRect(origin: .zero, size: bounds.size)
        mask.contents = model.pattern.withRenderingMode(.alwaysTemplate).cgImage
        mask.contentsGravity = .center
        mask.contentsScale = model.pattern.scale

        gradientView.customMask = mask

        setNeedsLayout()
    }

    func setupStyle() {
        backgroundColor = .clear

        let xTilt = UIInterpolatingMotionEffect(
            keyPath: "startPoint.x",
            type: .tiltAlongHorizontalAxis
        )

        xTilt.minimumRelativeValue = 1
        xTilt.maximumRelativeValue = 0

        let yTilt = UIInterpolatingMotionEffect(
            keyPath: "startPoint.y",
            type: .tiltAlongVerticalAxis
        )

        yTilt.minimumRelativeValue = 1
        yTilt.maximumRelativeValue = 0

        let group = UIMotionEffectGroup()
        group.motionEffects = [xTilt, yTilt]

        gradientView.addMotionEffect(group)
    }

    func setupLayout() {
        addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
