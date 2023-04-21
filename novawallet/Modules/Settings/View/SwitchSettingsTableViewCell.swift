import UIKit

protocol SwitchSettingsTableViewCellDelegate: AnyObject {
    func didChangeSwitchValue(model: SwitchSettingsCellViewModel?)
}

final class SwitchSettingsTableViewCell: CommonSettingsTableViewCell<UISwitch> {
    weak var delegate: SwitchSettingsTableViewCellDelegate?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        rightView.addTarget(self, action: #selector(actionSwitch), for: .valueChanged)
    }

    private var viewModel: SwitchSettingsCellViewModel?

    @objc private func actionSwitch(_: UISwitch) {
        delegate?.didChangeSwitchValue(model: viewModel)
    }

    func bind(viewModel: SwitchSettingsCellViewModel) {
        iconImageView.image = viewModel.icon
        titleLabel.text = viewModel.title
        subtitleLabel.text = nil
        rightView.isOn = viewModel.isOn
        self.viewModel = viewModel
    }
}
