import UIKit
import SnapKit

final class DAppDesktopModeSettingsView: UITableViewCell {
    var iconDetailsView: IconDetailsView { settingsView.iconDetailsView }
    var switchView: UISwitch { settingsView.switchView }
    var settingsView = DAppSettingsView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        iconDetailsView.apply(style: .regularSubheadline)
        iconDetailsView.detailsLabel.textAlignment = .left

        contentView.addSubview(settingsView)
        settingsView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0))
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
