import UIKit
import UIKit_iOS

final class ThumbView: RoundedView {
    private var thumbStyle: Style = .defaultStyle

    override init(frame: CGRect) {
        super.init(frame: frame)

        apply(style: thumbStyle)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension ThumbView {
    struct Style {
        let color: UIColor
        let cornerRadius: CGFloat

        static let defaultStyle = Style(color: .gray, cornerRadius: 10)
    }

    func apply(style: Style) {
        thumbStyle = style

        fillColor = thumbStyle.color
        cornerRadius = style.cornerRadius

        setNeedsLayout()
    }
}
