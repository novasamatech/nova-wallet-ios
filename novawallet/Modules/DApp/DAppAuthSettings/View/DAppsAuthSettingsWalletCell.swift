import Foundation
import UIKit

final class DAppsAuthSettingsWalletCell: UITableViewCell {
    let infoLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.numberOfLines = 0
        return label
    }()

    let walletView = StackTableCell()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(infoLabel)
        infoLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16.0)
            make.leading.trailing.equalToSuperview().inset(16.0)
        }

        contentView.addSubview(walletView)
        walletView.snp.makeConstraints { make in
            make.top.equalTo(infoLabel.snp.bottom).offset(8.0)
            make.leading.trailing.equalTo(16.0)
            make.height.equalTo(44.0)
            make.bottom.equalToSuperview()
        }
    }
}
