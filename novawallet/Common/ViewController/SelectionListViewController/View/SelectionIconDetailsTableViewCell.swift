import UIKit

final class ChainAssetSelectionTableViewCell: UITableViewCell {
    let radioButtonImageView: UIImageView = .create { view in
        view.image = R.image.iconRadioButtonUnselected()
    }

    let assetIconView: AssetIconView = .create { view in
        view.backgroundView.cornerRadius = Constants.iconSize.height / 2.0
        view.backgroundView.fillColor = R.color.colorContainerBackground()!
        view.backgroundView.highlightedFillColor = R.color.colorContainerBackground()!
    }

    let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .p1Paragraph
    }

    let subtitleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextSecondary()
        view.font = .p2Paragraph
    }

    private var viewModel: SelectableIconDetailsListViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.icon?.cancel(on: assetIconView.imageView)
        viewModel?.removeObserver(self)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellBackgroundPressed()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(assetIconView)

        assetIconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(Constants.assetIconLeadingOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(assetIconView.snp.right).offset(Constants.labelLeadingOffset)
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.titleTopInset)
        }

        contentView.addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints { make in
            make.left.equalTo(assetIconView.snp.right).offset(Constants.labelLeadingOffset)
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(Constants.subtitleBottomInset)
        }

        contentView.addSubview(radioButtonImageView)

        radioButtonImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.left.greaterThanOrEqualTo(titleLabel)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.radioButtonSize)
        }
    }

    private func updateSelectionState() {
        radioButtonImageView.image = (viewModel?.isSelected ?? false)
            ? R.image.iconRadioButtonSelected()
            : R.image.iconRadioButtonUnselected()
    }
}

extension ChainAssetSelectionTableViewCell: SelectionItemViewProtocol {
    func bind(viewModel: SelectableViewModelProtocol) {
        guard let iconDetailsViewModel = viewModel as? SelectableIconDetailsListViewModel else {
            return
        }

        self.viewModel = iconDetailsViewModel

        titleLabel.text = iconDetailsViewModel.title
        subtitleLabel.text = iconDetailsViewModel.subtitle

        assetIconView.bind(
            viewModel: iconDetailsViewModel.icon,
            size: Constants.iconSize
        )

        updateSelectionState()

        iconDetailsViewModel.addObserver(self)
    }
}

extension ChainAssetSelectionTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}

extension ChainAssetSelectionTableViewCell {
    private enum Constants {
        static let iconSize: CGSize = .init(width: 44.0, height: 44.0)
        static let assetIconLeadingOffset: CGFloat = 16.0
        static let labelLeadingOffset: CGFloat = 12.0
        static let titleTopInset: CGFloat = 9.0
        static let subtitleBottomInset: CGFloat = 9.0
        static let radioButtonSize: CGFloat = 20.0
    }
}
