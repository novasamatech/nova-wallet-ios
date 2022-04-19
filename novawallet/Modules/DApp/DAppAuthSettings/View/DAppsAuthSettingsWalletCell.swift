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

    let walletView: StackTableCell = {
        let view = StackTableCell()
        view.borderView.borderType = []
        view.contentInsets = .zero
        return view
    }()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: DisplayWalletViewModel) {
        walletView.bind(viewModel: viewModel.cellViewModel)
    }

    private func setupLocalization() {
        infoLabel.text = R.string.localizable.dappAuthorizedInfo(
            preferredLanguages: locale.rLanguages
        )

        walletView.titleLabel.text = R.string.localizable.commonWallet(
            preferredLanguages: locale.rLanguages
        )
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
            make.leading.trailing.equalToSuperview().inset(16.0)
            make.height.equalTo(44.0)
            make.bottom.equalToSuperview()
        }
    }
}
