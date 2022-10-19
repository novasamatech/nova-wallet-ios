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
        let fillColor: UIColor
        let highlightedFillColor: UIColor
        let cornerRadius: CGFloat
    }

    func apply(style: Style) {
        fillColor = style.fillColor
        highlightedFillColor = style.highlightedFillColor
        cornerRadius = style.cornerRadius
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
