import UIKit
import SubstrateSdk

protocol CustomValidatorCellDelegate: AnyObject {
    func didTapInfoButton(in cell: CustomValidatorCell)
}

class CustomValidatorCell: UITableViewCell {
    weak var delegate: CustomValidatorCellDelegate?

    let selectionImageView: UIImageView = {
        let imageView = UIImageView()
        return imageView
    }()

    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = .clear
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textAlignment = .right
        label.textColor = R.color.colorWhite()
        return label
    }()

    let detailsAuxLabel: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.textAlignment = .right
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        let icon = R.image.iconInfoFilled()?.tinted(with: R.color.colorWhite40()!)
        button.setImage(icon, for: .normal)
        return button
    }()

    let statusStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 2.0
        stackView.alignment = .center
        stackView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return stackView
    }()

    let detailsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return stackView
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

    private func configure() {
        backgroundColor = .clear
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear

        infoButton.addTarget(self, action: #selector(tapInfoButton), for: .touchUpInside)
    }

    private func setupLayout() {
        contentView.addSubview(selectionImageView)
        selectionImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalTo(selectionImageView.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(infoButton)
        infoButton.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.trailing.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(statusStackView)
        statusStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(4)
        }

        detailsStackView.addArrangedSubview(detailsLabel)
        detailsStackView.addArrangedSubview(detailsAuxLabel)

        contentView.addSubview(detailsStackView)
        detailsStackView.snp.makeConstraints { make in
            make.leading.equalTo(statusStackView.snp.trailing).offset(8)
            make.trailing.equalTo(infoButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }
    }

    @objc
    private func tapInfoButton() {
        delegate?.didTapInfoButton(in: self)
    }

    func bind(viewModel: CustomValidatorCellViewModel) {
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.address
        }

        clearStatusView()
        setupStatus(for: viewModel.shouldShowWarning, shouldShowError: viewModel.shouldShowError)

        if let auxDetailsText = viewModel.auxDetails {
            detailsLabel.text = viewModel.details
            detailsAuxLabel.text = auxDetailsText
            detailsLabel.isHidden = false
        } else {
            detailsAuxLabel.text = viewModel.details
            detailsLabel.isHidden = true
        }

        selectionImageView.image = viewModel.isSelected ? R.image.iconCheckbox() : R.image.iconCheckboxEmpty()
    }

    func bind(viewModel: ValidatorSearchCellViewModel) {
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.address
        }

        clearStatusView()
        setupStatus(for: viewModel.shouldShowWarning, shouldShowError: viewModel.shouldShowError)

        detailsLabel.isHidden = true

        detailsAuxLabel.text = viewModel.details

        selectionImageView.image = viewModel.isSelected ? R.image.iconCheckbox() : R.image.iconCheckboxEmpty()
    }

    private func clearStatusView() {
        let arrangedSubviews = statusStackView.arrangedSubviews

        arrangedSubviews.forEach {
            statusStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func setupStatus(for shouldShowWarning: Bool, shouldShowError: Bool) {
        if shouldShowWarning {
            statusStackView.addArrangedSubview(UIImageView(image: R.image.iconWarning()))
        }

        if shouldShowError {
            statusStackView.addArrangedSubview(UIImageView(image: R.image.iconErrorFilled()))
        }
    }
}
