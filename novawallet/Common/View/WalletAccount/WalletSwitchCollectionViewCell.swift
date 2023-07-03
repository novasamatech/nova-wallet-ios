import UIKit

final class WalletSwitchCollectionViewCell: UICollectionViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldTitle3
        label.textColor = R.color.colorTextPrimary()
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

    func bind(title: String) {
        titleLabel.text = title
    }

    func bind(viewModel: WalletSwitchViewModel) {
        walletSwitch.bind(viewModel: viewModel)
    }

    private func setupLayout() {
        contentView.addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(10.0)
            make.size.equalTo(UIConstants.walletSwitchSize)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(walletSwitch)
            make.trailing.equalTo(walletSwitch.snp.leading).offset(-8.0)
        }
    }
}
