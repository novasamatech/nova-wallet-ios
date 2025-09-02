import UIKit
import SubstrateSdk

protocol CollatorSelectionCellDelegate: AnyObject {
    func didTapInfoButton(in cell: CollatorSelectionCell)
}

class CollatorSelectionCell: UITableViewCell {
    enum DisplayType {
        case accentOnSorting
        case accentOnDetails
    }

    weak var delegate: CollatorSelectionCellDelegate?

    var isInfoEnabled: Bool {
        get {
            infoButton.isUserInteractionEnabled
        }

        set {
            infoButton.isUserInteractionEnabled = newValue
        }
    }

    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = .clear
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextPrimary()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let detailsView: UILabel = {
        let label = UILabel()
        label.font = .caption1
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let sortingByView: MultiValueView = {
        let view = MultiValueView()
        view.valueTop.font = .regularFootnote
        view.valueBottom.font = .regularFootnote
        return view
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        let icon = R.image.iconInfoFilled()
        button.setImage(icon, for: .normal)
        return button
    }()

    let warningView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconWarning()
        view.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
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

    func bind(viewModel: CollatorSelectionViewModel, type: DisplayType) {
        iconView.bind(icon: viewModel.iconViewModel)

        if let name = viewModel.collator.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.collator.address
        }

        applyDetails(
            title: viewModel.detailsName,
            subtitle: viewModel.details,
            displayType: type
        )

        switch type {
        case .accentOnSorting:
            sortingByView.valueTop.textColor = R.color.colorTextPositive()
        case .accentOnDetails:
            sortingByView.valueTop.textColor = R.color.colorTextPrimary()
        }

        sortingByView.valueTop.text = viewModel.sortedByTitle
        sortingByView.valueBottom.text = viewModel.sortedByDetails

        warningView.isHidden = !viewModel.hasWarning

        setNeedsLayout()
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
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()

        infoButton.addTarget(self, action: #selector(tapInfoButton), for: .touchUpInside)
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
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
            make.top.equalToSuperview().inset(5.0)
        }

        contentView.addSubview(detailsView)
        detailsView.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.bottom.equalToSuperview().inset(5.0)
        }

        contentView.addSubview(warningView)
        warningView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(4.0)
            make.bottom.equalTo(titleLabel)
        }

        contentView.addSubview(sortingByView)
        sortingByView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(warningView.snp.trailing).offset(40.0)
            make.leading.greaterThanOrEqualTo(detailsView.snp.trailing).offset(40.0)
            make.trailing.equalTo(infoButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }
    }

    private func applyDetails(title: String, subtitle: String, displayType: DisplayType) {
        let subtitleColor: UIColor

        let attributedString = NSMutableAttributedString(
            string: title,
            attributes: [
                .foregroundColor: R.color.colorTextSecondary()!
            ]
        )

        switch displayType {
        case .accentOnDetails:
            subtitleColor = R.color.colorTextPositive()!
        case .accentOnSorting:
            subtitleColor = R.color.colorTextPrimary()!
        }

        let subtitleAttributedString = NSAttributedString(
            string: " " + subtitle,
            attributes: [
                .foregroundColor: subtitleColor
            ]
        )

        attributedString.append(subtitleAttributedString)

        detailsView.attributedText = attributedString
    }

    @objc
    private func tapInfoButton() {
        delegate?.didTapInfoButton(in: self)
    }
}
