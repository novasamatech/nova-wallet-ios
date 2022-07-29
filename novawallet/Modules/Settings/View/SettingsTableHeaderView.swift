import UIKit

final class SettingsTableHeaderView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h1Title
        return label
    }()

    let walletSwitch = WalletSwitchControl()

    let accountDetailsView: DetailsTriangularedView = {
        let detailsView = UIFactory().createDetailsView(with: .singleTitle, filled: false)
        detailsView.iconRadius = UIConstants.normalAddressIconSize.height / 2.0
        detailsView.titleLabel.lineBreakMode = .byTruncatingTail
        detailsView.titleLabel.font = .regularSubheadline
        detailsView.titleLabel.textColor = R.color.colorWhite()
        detailsView.actionImage = R.image.iconInfo()?.tinted(with: R.color.colorWhite48()!)
        detailsView.highlightedFillColor = R.color.colorHighlightedAccent()!
        detailsView.strokeColor = R.color.colorWhite32()!
        detailsView.borderWidth = 1
        detailsView.horizontalSpacing = 12.0
        return detailsView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(walletSwitch)
        walletSwitch.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(10.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(UIConstants.walletSwitchSize)
        }

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(walletSwitch.snp.centerY)
        }

        addSubview(accountDetailsView)
        accountDetailsView.snp.makeConstraints { make in
            make.top.equalTo(walletSwitch.snp.bottom).offset(16.0)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }
    }
}
