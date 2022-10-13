import UIKit

final class ThumbLayer: CALayer {
    private var thumbStyle: Style = .defaultStyle
    private let shapeLayer: CAShapeLayer

    override init() {
        shapeLayer = .init()

        super.init()

        addSublayer(shapeLayer)
        apply(style: thumbStyle)
    }

    override init(layer: Any) {
        guard let other = layer as? ThumbLayer else {
            fatalError()
        }
        thumbStyle = other.thumbStyle
        shapeLayer = other.shapeLayer

        super.init(layer: layer)
        apply(style: thumbStyle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers() {
        let thumbPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: thumbStyle.cornerRadius
        )

        shapeLayer.path = thumbPath.cgPath
    }
}

extension ThumbLayer {
    struct Style {
        let color: UIColor
        let cornerRadius: CGFloat

        static let defaultStyle = Style(color: .gray, cornerRadius: 10)
    }

    func apply(style: Style) {
        thumbStyle = style

        shapeLayer.fillColor = thumbStyle.color.cgColor

        setNeedsLayout()
    }
}
