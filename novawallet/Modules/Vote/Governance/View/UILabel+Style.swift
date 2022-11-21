import UIKit
import SoraUI

extension UILabel {
    struct Style {
        let textColor: UIColor?
        let font: UIFont
    }

    convenience init(style: Style, textAlignment: NSTextAlignment = .left, numberOfLines: Int = 0) {
        self.init()
        self.textAlignment = textAlignment
        self.numberOfLines = numberOfLines
        apply(style: style)
    }

    func apply(style: Style) {
        textColor = style.textColor
        font = style.font
    }
}

extension RoundedView {
    struct Style {
        var shadow: ShadowShapeView.Style?
        var strokeWidth: CGFloat?
        var strokeColor: UIColor?
        var highlightedStrokeColor: UIColor?
        var fillColor: UIColor
        var highlightedFillColor: UIColor
        var rounding: Rounding?

        struct Rounding {
            let radius: CGFloat
            let corners: UIRectCorner
        }

        init(
            shadowOpacity: Float? = nil,
            strokeWidth: CGFloat? = nil,
            strokeColor: UIColor? = nil,
            highlightedStrokeColor: UIColor? = nil,
            fillColor: UIColor,
            highlightedFillColor: UIColor,
            rounding: RoundedView.Style.Rounding? = nil
        ) {
            if let shadowOpacity = shadowOpacity {
                shadow = ShadowShapeView.Style(
                    shadowOpacity: shadowOpacity,
                    shadowColor: nil,
                    shadowRadius: nil,
                    shadowOffset: nil
                )
            } else {
                shadow = nil
            }
            self.strokeWidth = strokeWidth
            self.strokeColor = strokeColor
            self.highlightedStrokeColor = highlightedStrokeColor
            self.fillColor = fillColor
            self.highlightedFillColor = highlightedFillColor
            self.rounding = rounding
        }

        init(
            shadow: ShadowShapeView.Style,
            strokeWidth: CGFloat? = nil,
            strokeColor: UIColor? = nil,
            highlightedStrokeColor: UIColor? = nil,
            fillColor: UIColor,
            highlightedFillColor: UIColor,
            rounding: RoundedView.Style.Rounding? = nil
        ) {
            self.shadow = shadow
            self.strokeWidth = strokeWidth
            self.strokeColor = strokeColor
            self.highlightedStrokeColor = highlightedStrokeColor
            self.fillColor = fillColor
            self.highlightedFillColor = highlightedFillColor
            self.rounding = rounding
        }
    }

    func apply(style: Style) {
        style.shadow.map { apply(style: $0) }
        style.strokeWidth.map { strokeWidth = $0 }
        style.strokeColor.map { strokeColor = $0 }
        style.highlightedStrokeColor.map { highlightedStrokeColor = $0 }

        fillColor = style.fillColor
        highlightedFillColor = style.highlightedFillColor

        style.rounding.map {
            roundingCorners = $0.corners
            cornerRadius = $0.radius
        }
    }
}

extension ShadowShapeView {
    struct Style {
        let shadowOpacity: Float?
        let shadowColor: UIColor?
        let shadowRadius: CGFloat?
        let shadowOffset: CGSize?
    }

    func apply(style: Style) {
        style.shadowOpacity.map { shadowOpacity = $0 }
        style.shadowColor.map { shadowColor = $0 }
        style.shadowRadius.map { shadowRadius = $0 }
        style.shadowOffset.map { shadowOffset = $0 }
    }
}

extension IconDetailsView {
    struct Style {
        let tintColor: UIColor
        let font: UIFont
    }

    func apply(style: Style) {
        detailsLabel.apply(style: .init(textColor: style.tintColor, font: style.font))
        imageView.tintColor = style.tintColor
    }
}

extension IconDetailsView {
    func bind(viewModel: TitleIconViewModel?) {
        imageView.image = viewModel?.icon
        detailsLabel.text = viewModel?.title
    }
}

extension UILabel.Style {
    static let footnotePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularFootnote
    )

    static let footnoteSecondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .regularFootnote
    )

    static let caption1Secondary = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .caption1
    )

    static let regularSubhedlinePrimary = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularSubheadline
    )
}

extension UILabel.Style {
    static let rowLink = UILabel.Style(
        textColor: R.color.colorButtonTextAccent(),
        font: .p2Paragraph
    )
}

extension RoundedView.Style {
    static let chips = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: R.color.colorChipsBackground()!,
        highlightedFillColor: R.color.colorChipsBackground()!
    )

    static func roundedChips(radius: CGFloat) -> RoundedView.Style {
        var chipsStyle = RoundedView.Style.chips
        chipsStyle.rounding = .init(radius: radius, corners: .allCorners)
        return chipsStyle
    }

    static let container = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0.5,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: R.color.colorContainerBorder(),
        fillColor: R.color.colorContainerBackground()!,
        highlightedFillColor: R.color.colorContainerBackground()!
    )

    static let assetContainer = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0.5,
        strokeColor: R.color.colorContainerBorder(),
        highlightedStrokeColor: R.color.colorContainerBorder(),
        fillColor: R.color.colorTokenContainerBackground()!,
        highlightedFillColor: R.color.colorTokenContainerBackground()!
    )

    static let nft = RoundedView.Style(
        shadow: .init(
            shadowOpacity: 1,
            shadowColor: UIColor.black.withAlphaComponent(0.56),
            shadowRadius: 4,
            shadowOffset: .init(width: 4, height: 0)
        ),
        strokeWidth: 0,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 8, corners: .allCorners)
    )

    static let lastNft = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: .clear,
        highlightedFillColor: .clear,
        rounding: .init(radius: 8, corners: .allCorners)
    )

    static let textField = RoundedView.Style(
        shadowOpacity: 0,
        strokeWidth: 0,
        fillColor: R.color.colorInputBackground()!,
        highlightedFillColor: R.color.colorInputBackground()!
    )
}
