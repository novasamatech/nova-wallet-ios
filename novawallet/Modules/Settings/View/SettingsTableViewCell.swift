import UIKit
import UIKit_iOS

class SettingsTableViewCell: SettingsBaseTableViewCell<UIImageView> {
    var accessoryArrowView: UIImageView { rightView }

    override func setupStyle() {
        super.setupStyle()

        accessoryArrowView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
    }

    override func setupLayout() {
        super.setupLayout()

        accessorySize = CGSize(width: 16, height: 16)
    }
}
