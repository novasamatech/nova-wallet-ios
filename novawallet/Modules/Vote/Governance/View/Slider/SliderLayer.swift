import UIKit

final class SliderLayer: CALayer {
    private let firstSegment: CAShapeLayer
    private let lastSegment: CAShapeLayer
    private var sliderStyle: Style = .defaultStyle
    var gap: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(layer: Any) {
        guard let other = layer as? SliderLayer else {
            fatalError()
        }
        firstSegment = other.firstSegment
        lastSegment = other.lastSegment
        sliderStyle = other.sliderStyle

        super.init(layer: layer)
    }

    override init() {
        firstSegment = CAShapeLayer()
        lastSegment = CAShapeLayer()

        super.init()

        addSublayer(firstSegment)
        addSublayer(lastSegment)

        apply(style: sliderStyle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSublayers() {
        let lineCalculationSize = CGSize(
            width: bounds.width - sliderStyle.dividerSpace,
            height: bounds.height
        )
        let firstSegmentSize = lineCalculationSize.applying(.init(scaleX: gap, y: 1))
        let lastSegmentSize = lineCalculationSize.applying(.init(scaleX: 1 - gap, y: 1))
        let space = firstSegmentSize.width + sliderStyle.dividerSpace
        let lastSegmentOrigin = bounds.origin.applying(.init(
            translationX: space,
            y: 0
        ))

        let firstPath = UIBezierPath(
            roundedRect: .init(origin: bounds.origin, size: firstSegmentSize),
            cornerRadius: sliderStyle.cornerRadius
        )
        let lastPath = UIBezierPath(
            roundedRect: .init(origin: lastSegmentOrigin, size: lastSegmentSize),
            cornerRadius: sliderStyle.cornerRadius
        )

        firstSegment.path = firstPath.cgPath
        lastSegment.path = lastPath.cgPath
    }
}

extension SliderLayer {
    struct Style {
        let firstColor: UIColor
        let lastColor: UIColor
        let cornerRadius: CGFloat
        let dividerSpace: CGFloat

        static let defaultStyle = Style(
            firstColor: .green,
            lastColor: .red,
            cornerRadius: 4,
            dividerSpace: 6
        )
    }

    func apply(style: Style) {
        sliderStyle = style
        firstSegment.fillColor = style.firstColor.cgColor
        lastSegment.fillColor = style.lastColor.cgColor
        setNeedsLayout()
    }
}
