import UIKit
import SoraUI

extension StackTitleValueIconView {
    struct Style {
        let title: UILabel.Style
        let value: UILabel.Style
        let icon: UIImage?
        let iconBorderStyle: RoundedView.Style
    }

    func apply(style: Style) {
        rowContentView.fView.fView.apply(style: style.title)
        rowContentView.sView.apply(style: style.value)
        rowContentView.fView.sView.image = style.icon
        rowContentView.fView.sView.borderView.apply(style: style.iconBorderStyle)
    }
}
