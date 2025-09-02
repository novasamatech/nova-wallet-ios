import UIKit_iOS

extension RoundedButton {
    struct Style {
        let background: RoundedView.Style
        let title: UILabel.Style
    }

    func apply(style: Style) {
        roundedBackgroundView?.apply(style: style.background)
        imageWithTitleView?.titleFont = style.title.font
        imageWithTitleView?.titleColor = style.title.textColor
    }
}
