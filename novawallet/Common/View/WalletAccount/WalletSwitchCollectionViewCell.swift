import UIKit

<<<<<<< HEAD:novawallet/Modules/AssetList/View/AssetListAccountCell.swift
final class AssetListAccountCell: UICollectionViewCell {
    let walletConnect = WalletConnectionsView()

=======
final class WalletSwitchCollectionViewCell: UICollectionViewCell {
>>>>>>> develop:novawallet/Common/View/WalletAccount/WalletSwitchCollectionViewCell.swift
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .semiBoldTitle3
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .center
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

<<<<<<< HEAD:novawallet/Modules/AssetList/View/AssetListAccountCell.swift
        walletSwitch.bind(viewModel: viewModel.walletSwitch)

        let walletConnectViewModel: WalletConnectionsView.Model
        if let walletConnectionsCount = viewModel.walletConnectSessionsCount {
            walletConnectViewModel = .activeConections(walletConnectionsCount)
        } else {
            walletConnectViewModel = .empty
        }

        walletConnect.bind(
            model: walletConnectViewModel,
            animated: true
        )

        setNeedsLayout()
        layoutIfNeeded()
=======
    func bind(viewModel: WalletSwitchViewModel) {
        walletSwitch.bind(viewModel: viewModel)
>>>>>>> develop:novawallet/Common/View/WalletAccount/WalletSwitchCollectionViewCell.swift
    }

    private func setupLayout() {
        contentView.addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(10.0)
            make.size.equalTo(UIConstants.walletSwitchSize)
        }

        contentView.addSubview(walletConnect)
        walletConnect.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(10.0)
            make.size.equalTo(CGSize(width: 89.0, height: 40.0))
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(walletSwitch)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualTo(walletConnect.snp.trailing)
            make.trailing.lessThanOrEqualTo(walletSwitch.snp.leading)
        }
    }
}
