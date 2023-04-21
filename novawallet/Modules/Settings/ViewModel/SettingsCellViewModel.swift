import UIKit.UIImage

enum SettingsCellViewModel {
    case details(DetailsSettingsCellViewModel)
    case toggle(SwitchSettingsCellViewModel)

    var row: SettingsRow {
        switch self {
        case let .details(navigationSettingsCellViewModel):
            return navigationSettingsCellViewModel.row
        case let .toggle(switchSettingsCellViewModel):
            return switchSettingsCellViewModel.row
        }
    }
}

struct SwitchSettingsCellViewModel {
    let row: SettingsRow
    let title: String
    let icon: UIImage?
    let isOn: Bool
}

struct DetailsSettingsCellViewModel {
    let row: SettingsRow
    let title: String
    let icon: UIImage?
    let accessoryTitle: String?
}
