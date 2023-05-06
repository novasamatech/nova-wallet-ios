import UIKit

final class SettingsSubtitleTableViewCell: SettingsAccessoryTableViewCell<UILabel> {
    override func setupStyle() {
        super.setupStyle()

        accessoryDisplayView.apply(style: .regularSubhedlineSecondary)
    }

    func bind(titleViewModel: TitleIconViewModel, accessoryViewModel: String) {
        super.bind(titleViewModel: titleViewModel)

        accessoryDisplayView.text = accessoryViewModel
    }
}
