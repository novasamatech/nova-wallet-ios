import Foundation
import SubstrateSdk

class YourValidatorTableCell: UITableViewCell {
    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = .clear
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite()!
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return label
    }()

    let warningImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarning()
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return imageView
    }()

    let errorImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSlash()
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return imageView
    }()

    let infoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconInfoFilled()?.tinted(with: R.color.colorWhite48()!)
        return imageView
    }()

    let apyLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTransparentText()
        label.font = .regularFootnote
        label.textAlignment = .right
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return label
    }()

    let mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.layoutMargins = UIEdgeInsets(
            top: 8,
            left: UIConstants.horizontalInset,
            bottom: 8,
            right: UIConstants.horizontalInset
        )
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.axis = .horizontal
        stackView.alignment = .center
        return stackView
    }()

    let labelsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()

    let iconsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 4.0
        return stackView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorHighlightedAccent()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        mainStackView.addArrangedSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }

        mainStackView.addArrangedSubview(labelsStackView)

        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(detailsLabel)

        mainStackView.addArrangedSubview(iconsStackView)

        iconsStackView.addArrangedSubview(warningImageView)
        iconsStackView.addArrangedSubview(errorImageView)
        iconsStackView.addArrangedSubview(apyLabel)

        mainStackView.addArrangedSubview(infoImageView)
        infoImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
        }

        mainStackView.setCustomSpacing(12, after: iconView)
        mainStackView.setCustomSpacing(4.0, after: labelsStackView)
        mainStackView.setCustomSpacing(8.0, after: iconsStackView)
    }

    func bind(viewModel: YourValidatorViewModel, for locale: Locale) {
        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.text = viewModel.address
            titleLabel.lineBreakMode = .byTruncatingMiddle
        }

        if let amount = viewModel.amount {
            let prefixString = R.string.localizable.stakingYourNominatedPrefix(
                preferredLanguages: locale.rLanguages
            )

            let details = NSMutableAttributedString()

            details.append(
                NSAttributedString(
                    string: prefixString,
                    attributes: [.foregroundColor: R.color.colorTransparentText()!]
                )
            )

            details.append(
                NSAttributedString(
                    string: amount,
                    attributes: [.foregroundColor: R.color.colorWhite()!]
                )
            )

            detailsLabel.attributedText = details
        } else {
            detailsLabel.attributedText = nil
        }

        iconView.bind(icon: viewModel.icon)

        warningImageView.isHidden = !viewModel.shouldHaveWarning
        errorImageView.isHidden = !viewModel.shouldHaveError

        if let apy = viewModel.apy {
            apyLabel.text = apy
        } else {
            apyLabel.text = nil
        }
    }
}
