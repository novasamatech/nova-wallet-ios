import UIKit

final class BalanceCardView: UIView {
    let backgroundImage = R.image.cardBg()!
    let patternImage = R.image.cardBigPattern()!

    let gradientView = MultigradientView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        context.addPath(path.cgPath)
        context.clip()

        let backgroundRect = centerFillRect(for: rect, imageSize: backgroundImage.size)

        backgroundImage.draw(in: backgroundRect)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let mask = CALayer()
        mask.frame = CGRect(origin: .zero, size: bounds.size)
        mask.contents = patternImage.withRenderingMode(.alwaysTemplate).cgImage
        mask.contentsGravity = .center
        mask.contentsScale = patternImage.scale

        gradientView.customMask = mask
    }

    private func setupStyle() {
        backgroundColor = .clear

        gradientView.gradientType = .radial
        gradientView.colors = [
            UIColor(hex: "#FBACFF")!,
            UIColor(hex: "#D99EFF")!.withAlphaComponent(0.76),
            UIColor(hex: "#BC92FF")!.withAlphaComponent(0.56),
            UIColor(hex: "#A388FF")!.withAlphaComponent(0.39),
            UIColor(hex: "#8F7FFF")!.withAlphaComponent(0.25),
            UIColor(hex: "#7F79FF")!.withAlphaComponent(0.14),
            UIColor(hex: "#7374FF")!.withAlphaComponent(0.06),
            UIColor(hex: "#6D71FF")!.withAlphaComponent(0.02),
            UIColor(hex: "#6B71FF")!.withAlphaComponent(0.0)
        ]

        gradientView.locations = [0.0, 0.12, 0.25, 0.37, 0.50, 0.62, 0.75, 0.87, 1.0]

        gradientView.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientView.endPoint = CGPoint(x: 1, y: 1)

        let xTilt = UIInterpolatingMotionEffect(
            keyPath: "startPoint.x",
            type: .tiltAlongHorizontalAxis
        )

        xTilt.minimumRelativeValue = 0
        xTilt.maximumRelativeValue = 1

        let yTilt = UIInterpolatingMotionEffect(
            keyPath: "startPoint.y",
            type: .tiltAlongVerticalAxis
        )

        yTilt.minimumRelativeValue = 0
        yTilt.maximumRelativeValue = 1

        let group = UIMotionEffectGroup()
        group.motionEffects = [xTilt, yTilt]

        gradientView.addMotionEffect(group)
    }

    private func setupLayout() {
        addSubview(gradientView)

        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func aspectFillRect(for rect: CGRect, imageSize: CGSize) -> CGRect {
        var drawingSize = CGSize(
            width: rect.size.width,
            height: rect.size.width * imageSize.height / imageSize.width
        )

        if drawingSize.height < rect.size.height {
            drawingSize.height = rect.size.height
            drawingSize.width = rect.size.height * imageSize.width / imageSize.height
        }

        let origin = CGPoint(
            x: rect.midX - drawingSize.width / 2,
            y: rect.midY - drawingSize.height / 2
        )

        return CGRect(origin: origin, size: drawingSize)
    }

    private func centerFillRect(for rect: CGRect, imageSize: CGSize) -> CGRect {
        let origin = CGPoint(
            x: rect.midX - imageSize.width / 2,
            y: rect.midY - imageSize.height / 2
        )

        return CGRect(origin: origin, size: imageSize)
    }
}
