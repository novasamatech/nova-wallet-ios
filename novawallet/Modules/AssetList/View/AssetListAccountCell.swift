import UIKit

final class AssetListAccountCell: UICollectionViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldTitle3
        label.textColor = R.color.colorWhite()
        return label
    }()

    let walletSwitch = WalletSwitchControl()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetListHeaderViewModel) {
        titleLabel.text = viewModel.title

        walletSwitch.bind(viewModel: viewModel.walletSwitch)
    }

    private func setupLayout() {
        contentView.addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(10.0)
            make.size.equalTo(CGSize(width: 79.0, height: 40.0))
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(walletSwitch)
            make.trailing.equalTo(walletSwitch.snp.leading).offset(-8.0)
        }
    }
}
