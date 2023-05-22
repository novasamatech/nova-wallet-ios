import UIKit.UIImage

struct SettingsCellViewModel {
    enum Accessory {
        case title(String)
        case box(TitleIconViewModel)
        case switchControl(isOn: Bool)
        case none

        init(optTitle: String?) {
            if let title = optTitle {
                self = .title(title)
            } else {
                self = .none
            }
        }

        init(optTitle: String?, icon: UIImage?) {
            if let title = optTitle {
                self = .box(.init(title: title, icon: icon))
            } else {
                self = .none
            }
        }
    }

    let row: SettingsRow
    let title: TitleIconViewModel
    let accessory: Accessory
}
