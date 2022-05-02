import UIKit

final class StakingRewardHistoryTableCell: UITableViewCell {
    private enum Constants {
        static let verticalInset: CGFloat = 8
    }

    private let iconView = AssetIconView.cellRewards()

    private let addressLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = R.color.colorWhite()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let daysLeftLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let tokenAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorWhite()
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    private let usdAmountLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite48()
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.colorAccentSelected()!
        self.selectedBackgroundView = selectedBackgroundView
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(2 * iconView.backgroundView.cornerRadius)
        }

        contentView.addSubview(addressLabel)
        addressLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.top.equalToSuperview().inset(Constants.verticalInset)
        }

        contentView.addSubview(daysLeftLabel)
        daysLeftLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12.0)
            make.top.equalTo(addressLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
        }

        contentView.addSubview(tokenAmountLabel)
        tokenAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.verticalInset)
            make.leading.greaterThanOrEqualTo(addressLabel.snp.trailing).offset(12)
        }

        contentView.addSubview(usdAmountLabel)
        usdAmountLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(tokenAmountLabel.snp.bottom)
            make.bottom.equalToSuperview().inset(Constants.verticalInset)
            make.leading.greaterThanOrEqualTo(daysLeftLabel.snp.trailing).offset(12)
        }
    }
}

extension StakingRewardHistoryTableCell {
    func bind(model: StakingRewardHistoryCellViewModel) {
        addressLabel.text = model.addressOrName
        daysLeftLabel.attributedText = model.daysLeftText
        tokenAmountLabel.text = model.tokenAmountText
        usdAmountLabel.text = model.usdAmountText
    }

    func bind(timeLeftText: NSAttributedString) {
        daysLeftLabel.attributedText = timeLeftText
    }
}
