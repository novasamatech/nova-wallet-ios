import UIKit

protocol SwitchSettingsTableViewCellDelegate: AnyObject {
    func didToggle(cell: SwitchSettingsTableViewCell)
}

final class SwitchSettingsTableViewCell: SettingsBaseTableViewCell<UISwitch> {
    weak var delegate: SwitchSettingsTableViewCellDelegate?

    @objc private func actionSwitch() {
        delegate?.didToggle(cell: self)
    }

    override func setupStyle() {
        super.setupStyle()

        rightView.tintColor = R.color.colorSwitchBackground()
        rightView.onTintColor = R.color.colorIndicatorActive()
        rightView.thumbTintColor = R.color.colorIconPrimary()
        rightView.addTarget(self, action: #selector(actionSwitch), for: .valueChanged)
    }

    func bind(titleViewModel: TitleIconViewModel, isOn: Bool) {
        super.bind(titleViewModel: titleViewModel)

        rightView.isOn = isOn
    }
}
