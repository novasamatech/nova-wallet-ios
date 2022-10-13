import UIKit

final class SegmentedSliderView: UIView {
    private var style: Style = .defaultStyle
    private var model: Model = .init()

    let slider = SliderLayer()
    let thumb = ThumbLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        layer.addSublayer(slider)
        layer.addSublayer(thumb)

        apply(style: style)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let sliderFrame = bounds.inset(by: style.lineInsets)
        slider.frame = sliderFrame

        guard let thumbStyle = style.thumbStyle else {
            thumb.frame = .zero
            return
        }

        let thumbValueDouble = NSDecimalNumber(decimal: model.thumbProgress).doubleValue
        let originX = sliderFrame.size.width * thumbValueDouble - thumbStyle.width / 2
        let thumbHeight = thumbStyle.height ?? bounds.size.height
        let originY = sliderFrame.midY - thumbHeight / 2
        let origin = CGPoint(x: min(bounds.maxX, max(originX, bounds.minX)), y: originY)
        let size = CGSize(width: thumbStyle.width, height: thumbHeight)

        thumb.frame = CGRect(origin: origin, size: size)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 11)
    }
}

extension SegmentedSliderView {
    typealias SliderStyle = SliderLayer.Style
    struct Style {
        let lineInsets: UIEdgeInsets
        let sliderStyle: SliderStyle
        let thumbStyle: ThumbStyle?

        static let defaultStyle = Style(
            lineInsets: .init(top: 3, left: 0, bottom: 3, right: 0),
            sliderStyle: .defaultStyle,
            thumbStyle: .defaultStyle
        )
    }

    struct ThumbStyle {
        let color: UIColor
        let cornerRadius: CGFloat
        let width: CGFloat
        let height: CGFloat?
        var shadow: ShadowStyle

        static let defaultStyle = ThumbStyle(
            color: .white,
            cornerRadius: 8,
            width: 3,
            height: nil,
            shadow: .defaultStyle
        )
    }

    struct ShadowStyle {
        let color: UIColor
        let opacity: Float
        let offset: CGSize
        let radius: CGFloat

        static let defaultStyle = ShadowStyle(
            color: UIColor(red: 0, green: 0, blue: 0, alpha: 0.72),
            opacity: 1,
            offset: .zero,
            radius: 8
        )
    }

    func apply(style: Style) {
        self.style = style
        slider.apply(style: style.sliderStyle)

        style.thumbStyle.map {
            thumb.apply(style: .init(color: $0.color, cornerRadius: $0.cornerRadius))
            thumb.shadowColor = $0.shadow.color.cgColor
            thumb.shadowOpacity = $0.shadow.opacity
            thumb.shadowOffset = $0.shadow.offset
            thumb.shadowRadius = $0.shadow.radius
        }

        setNeedsDisplay()
    }
}

extension SegmentedSliderView {
    struct Model {
        let thumbProgress: Decimal
        let value: Decimal?

        init(thumbProgress: Decimal = 0.0, value: Decimal? = nil) {
            self.thumbProgress = thumbProgress
            self.value = value
        }
    }

    func bind(viewModel: Model) {
        model = viewModel
        slider.gap = model.value.map { CGFloat(NSDecimalNumber(decimal: $0).floatValue) }

        setNeedsLayout()
    }
}
