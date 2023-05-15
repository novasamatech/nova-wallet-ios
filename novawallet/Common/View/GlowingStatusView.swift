import UIKit

final class GlowingStatusView: GenericPairValueView<GlowingView, UILabel> {
    var indicator: GlowingView { fView }
    var titleLabel: UILabel { sView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        setHorizontalAndSpacing(8)

        titleLabel.apply(style: .footnotePrimary)
    }
}

extension GlowingStatusView {
    struct Style {
        let backgroundColor: UIColor
        let mainColor: UIColor

        static var active: Style {
            let color = R.color.colorTextPositive()!
            return .init(
                backgroundColor: color.withAlphaComponent(0.4),
                mainColor: color
            )
        }

        static var inactive: Style {
            let color = R.color.colorTextNegative()!
            return .init(
                backgroundColor: color.withAlphaComponent(0.4),
                mainColor: color
            )
        }
    }

    func apply(style: Style) {
        indicator.outerFillColor = style.backgroundColor
        indicator.innerFillColor = style.mainColor
        titleLabel.textColor = style.mainColor
    }
}
