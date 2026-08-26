import SubstrateSdk
import UIKit

final class SubtensorSubnetCell: UITableViewCell {
    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = .clear
        return view
    }()

    let symbolLabel: UILabel = {
        let label = UILabel()
        label.font = .regularSubheadline
        label.textColor = R.color.colorTextPrimary()
        label.textAlignment = .center
        return label
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextPrimary()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textColor = R.color.colorTextSecondary()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let valuesView: MultiValueView = {
        let view = MultiValueView()
        view.valueTop.font = .regularFootnote
        view.valueTop.textColor = R.color.colorTextPrimary()
        view.valueBottom.font = .caption1
        view.valueBottom.textColor = R.color.colorTextSecondary()
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorSubnetSelectViewModel) {
        if let icon = viewModel.icon {
            iconView.isHidden = false
            symbolLabel.isHidden = true
            iconView.bind(icon: icon)
        } else {
            iconView.isHidden = true
            symbolLabel.isHidden = false
            symbolLabel.text = String(viewModel.subtitle.prefix(1))
        }

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle

        valuesView.valueTop.text = viewModel.price

        if let apr = viewModel.apr {
            valuesView.valueBottom.text = [apr, viewModel.aprDetail]
                .compactMap { $0 }
                .joined(separator: " ")
        } else {
            valuesView.valueBottom.text = nil
        }

        setNeedsLayout()
    }
}

private extension SubtensorSubnetCell {
    func configure() {
        backgroundColor = .clear
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()
    }

    func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(symbolLabel)
        symbolLabel.snp.makeConstraints { make in
            make.center.equalTo(iconView)
            make.size.equalTo(24)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.equalToSuperview().inset(6.0)
        }

        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.bottom.equalToSuperview().inset(6.0)
        }

        contentView.addSubview(valuesView)
        valuesView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
            make.leading.greaterThanOrEqualTo(subtitleLabel.snp.trailing).offset(8.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }
    }
}
