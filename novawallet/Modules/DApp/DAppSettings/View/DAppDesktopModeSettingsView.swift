import UIKit
import SnapKit

protocol DAppDesktopModeSettingsViewDelegate: AnyObject {
    func didChangeDesktopMode(isOn: Bool)
}

final class DAppDesktopModeSettingsView: UITableViewCell {
    weak var delegate: DAppDesktopModeSettingsViewDelegate?

    var iconDetailsView: IconDetailsView { settingsView.iconDetailsView }
    var switchView: UISwitch { settingsView.switchView }
    var settingsView = DAppSettingsView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        iconDetailsView.apply(style: .regularSubheadline)
        iconDetailsView.detailsLabel.textAlignment = .left
        iconDetailsView.spacing = 12
        contentView.addSubview(settingsView)
        settingsView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        }
        switchView.addTarget(self, action: #selector(didChangeSwitchValue), for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func didChangeSwitchValue(_ control: UISwitch) {
        delegate?.didChangeDesktopMode(isOn: control.isOn)
    }
}
