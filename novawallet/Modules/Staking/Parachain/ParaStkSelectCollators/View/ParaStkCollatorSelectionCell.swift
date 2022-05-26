import UIKit
import SubstrateSdk

protocol CollatorSelectionCellDelegate: AnyObject {
    func didTapInfoButton(in cell: CollatorSelectionCell)
}

class CollatorSelectionCell: UITableViewCell {
    enum DisplayType {
        case accentOnRewards
        case accentOnMinStake
    }

    weak var delegate: CollatorSelectionCellDelegate?

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

    let detailsView: TitleHorizontalMultiValueView = {
        let view = TitleHorizontalMultiValueView()
        view.detailsTitleLabel.textColor = R.color.colorTransparentText()
        view.detailsTitleLabel.font = .caption1
        view.detailsValueLabel.font = .regularFootnote
        view.spacing = 2.0
        return view
    }()

    let sortingByView: MultiValueView = {
        let view = MultiValueView()
        view.valueTop.font = .regularFootnote
        view.valueBottom.font = .regularFootnote
        return view
    }()

    let infoButton: UIButton = {
        let button = UIButton()
        let icon = R.image.iconInfoFilled()?.tinted(with: R.color.colorWhite40()!)
        button.setImage(icon, for: .normal)
        return button
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

    func bind(viewModel: CollatorSelectionViewModel, type: DisplayType, locale: Locale) {
        apply(type: type, locale: locale)
        apply(viewModel: viewModel)
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

        contentView.addSubview(sortingByView)
        sortingByView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(4.0)
            make.leading.greaterThanOrEqualTo(detailsView.snp.trailing).offset(4.0)
            make.trailing.equalTo(infoButton.snp.leading).offset(-4)
            make.centerY.equalToSuperview()
        }
    }

    private func apply(type: DisplayType, locale: Locale) {
        switch type {
        case .accentOnRewards:
            detailsView.detailsValueLabel.textColor = R.color.colorGreen()
            sortingByView.valueTop.textColor = R.color.colorWhite()
            detailsView.detailsTitleLabel.text = R.string.localizable.commonRewardsColumn(
                preferredLanguages: locale.rLanguages
            )
        case .accentOnMinStake:
            detailsView.detailsValueLabel.textColor = R.color.colorWhite()
            sortingByView.valueTop.textColor = R.color.colorGreen()
            detailsView.detailsTitleLabel.text = R.string.localizable.commonMinStakeColumn(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    private func apply(viewModel: CollatorSelectionViewModel) {
        iconView.bind(icon: viewModel.iconViewModel)

        titleLabel.text = viewModel.title
        detailsView.detailsValueLabel.text = viewModel.details
        sortingByView.valueTop.text = viewModel.sortedByTitle
        sortingByView.valueBottom.text = viewModel.sortedByDetails

        setNeedsLayout()
    }

    @objc
    private func tapInfoButton() {
        delegate?.didTapInfoButton(in: self)
    }
}
