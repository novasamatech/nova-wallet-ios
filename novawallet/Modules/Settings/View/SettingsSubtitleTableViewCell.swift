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

    func bind(title: String, accessoryViewModel: String) {
        super.bind(icon: nil, title: title)

        accessoryDisplayView.text = accessoryViewModel
    }

    override func set(active: Bool) {
        super.set(active: active)
        accessoryDisplayView.apply(style: active ? .regularSubhedlineSecondary : .regularSubhedlineInactive)
    }
}
