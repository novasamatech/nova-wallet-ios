import UIKit
import UIKit_iOS

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
