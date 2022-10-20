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
        var shadowOpacity: CFloat?
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
    }

    func apply(style: Style) {
        style.shadowOpacity.map { shadowOpacity = $0 }
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
    static let footnoteWhite64 = UILabel.Style(
        textColor: R.color.colorWhite64()!,
        font: .regularFootnote
    )
}

extension UILabel.Style {
    static let rowLink = UILabel.Style(
        textColor: R.color.colorAccent(),
        font: .p2Paragraph
    )
}
