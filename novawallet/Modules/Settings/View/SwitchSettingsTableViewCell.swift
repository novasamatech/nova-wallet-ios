import UIKit

protocol SwitchSettingsTableViewCellDelegate: AnyObject {
    func didChangeSwitchValue(model: SwitchSettingsCellViewModel?)
}

final class SwitchSettingsTableViewCell: CommonSettingsTableViewCell<UISwitch> {
    weak var delegate: SwitchSettingsTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    private var viewModel: SwitchSettingsCellViewModel?

    @objc private func actionSwitch() {
        delegate?.didChangeSwitchValue(model: viewModel)
    }

    private func setup() {
        rightView.tintColor = R.color.colorSwitchBackground()
        rightView.onTintColor = R.color.colorIndicatorActive()
        rightView.thumbTintColor = R.color.colorIconPrimary()
        rightView.addTarget(self, action: #selector(actionSwitch), for: .valueChanged)
        selectionStyle = .none
    }

    func bind(viewModel: SwitchSettingsCellViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title
        subtitleLabel.text = nil
        rightView.isOn = viewModel.isOn

        self.viewModel = viewModel
    }
}
