import UIKit
import UIKit_iOS

extension StackTitleValueIconView {
    struct Style {
        let title: UILabel.Style
        let value: UILabel.Style
        let icon: UIImage?
        let iconBorderStyle: RoundedView.Style
        let adjustsFontSizeToFitWidth: Bool
        let minimumScaleFactor: CGFloat

        init(
            title: UILabel.Style,
            value: UILabel.Style,
            icon: UIImage?,
            iconBorderStyle: RoundedView.Style,
            adjustsFontSizeToFitWidth: Bool = false,
            minimumScaleFactor: CGFloat = 0.5
        ) {
            self.title = title
            self.value = value
            self.icon = icon
            self.iconBorderStyle = iconBorderStyle
            self.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth
            self.minimumScaleFactor = minimumScaleFactor
        }
    }

    func apply(style: Style) {
        rowContentView.fView.fView.apply(style: style.title)
        rowContentView.sView.apply(style: style.value)
        rowContentView.fView.sView.image = style.icon
        rowContentView.fView.sView.borderView.apply(style: style.iconBorderStyle)
        rowContentView.fView.fView.adjustsFontSizeToFitWidth = style.adjustsFontSizeToFitWidth
        rowContentView.fView.fView.minimumScaleFactor = style.minimumScaleFactor
        rowContentView.sView.adjustsFontSizeToFitWidth = style.adjustsFontSizeToFitWidth
        rowContentView.sView.minimumScaleFactor = style.minimumScaleFactor
    }
}
