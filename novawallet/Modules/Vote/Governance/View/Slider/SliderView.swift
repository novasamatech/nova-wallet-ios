import UIKit
import UIKit_iOS

final class SliderView: UIView {
    private let firstSegment: RoundedView = .create { view in
        view.shadowOpacity = 0.0
    }

    private let lastSegment: RoundedView = .create { view in
        view.shadowOpacity = 0.0
    }

    private var sliderStyle: Style = .defaultStyle

    var gap: CGFloat? {
        didSet {
            if gap != oldValue {
                applyStyleAndLayout()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(firstSegment)
        addSubview(lastSegment)

        apply(style: sliderStyle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyStyleAndLayout() {
        firstSegment.cornerRadius = sliderStyle.cornerRadius
        lastSegment.cornerRadius = sliderStyle.cornerRadius

        if gap != nil {
            firstSegment.fillColor = sliderStyle.firstColor
            lastSegment.fillColor = sliderStyle.lastColor

            lastSegment.isHidden = false
        } else {
            firstSegment.fillColor = sliderStyle.zeroColor

            lastSegment.isHidden = true
        }

        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let gap = gap {
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

            firstSegment.frame = CGRect(origin: bounds.origin, size: firstSegmentSize)
            lastSegment.frame = CGRect(origin: lastSegmentOrigin, size: lastSegmentSize)
        } else {
            firstSegment.frame = bounds
        }
    }
}

extension SliderView {
    struct Style {
        let firstColor: UIColor
        let lastColor: UIColor
        let zeroColor: UIColor
        let cornerRadius: CGFloat
        let dividerSpace: CGFloat

        static let defaultStyle = Style(
            firstColor: .green,
            lastColor: .red,
            zeroColor: .gray,
            cornerRadius: 4,
            dividerSpace: 6
        )
    }

    func apply(style: Style) {
        sliderStyle = style

        applyStyleAndLayout()
    }
}
