import UIKit
import SoraUI

typealias SettingsTableViewCell = CommonSettingsTableViewCell<UIImageView>

extension SettingsTableViewCell {
    func setup() {
        accessorySize = .init(width: 16, height: 16)
        rightView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
    }

    func bind(viewModel: DetailsSettingsCellViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title

        subtitleLabel.text = viewModel.accessoryTitle
    }
}
