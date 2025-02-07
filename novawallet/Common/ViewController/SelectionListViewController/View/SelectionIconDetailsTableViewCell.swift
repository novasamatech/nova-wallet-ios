import UIKit

final class SelectionIconDetailsTableViewCell: UITableViewCell {
    let radioButtonImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconRadioButtonUnselected()
        return imageView
    }()

    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextPrimary()
        label.font = .p1Paragraph
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorTextSecondary()
        label.font = .p2Paragraph
        return label
    }()

    private var viewModel: SelectableIconDetailsListViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.icon?.cancel(on: iconImageView)
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
        contentView.addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16.0)
            make.centerY.equalToSuperview()
            make.size.equalTo(32.0)
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12.0)
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(7.0)
        }

        contentView.addSubview(subtitleLabel)

        subtitleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconImageView.snp.right).offset(12.0)
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(8.0)
        }

        contentView.addSubview(radioButtonImageView)

        radioButtonImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(UIConstants.horizontalInset)
            make.left.greaterThanOrEqualTo(titleLabel)
            make.centerY.equalToSuperview()
            make.size.equalTo(20.0)
        }
    }

    private func updateSelectionState() {
        radioButtonImageView.image = (viewModel?.isSelected ?? false)
            ? R.image.iconRadioButtonSelected()
            : R.image.iconRadioButtonUnselected()
    }
}

extension SelectionIconDetailsTableViewCell: SelectionItemViewProtocol {
    func bind(viewModel: SelectableViewModelProtocol) {
        guard let iconDetailsViewModel = viewModel as? SelectableIconDetailsListViewModel else {
            return
        }

        self.viewModel?.icon?.cancel(on: iconImageView)
        iconImageView.image = nil

        self.viewModel = iconDetailsViewModel

        titleLabel.text = iconDetailsViewModel.title
        subtitleLabel.text = iconDetailsViewModel.subtitle

        iconDetailsViewModel.icon?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32.0, height: 32.0),
            animated: true
        )

        updateSelectionState()

        iconDetailsViewModel.addObserver(self)
    }
}

extension SelectionIconDetailsTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
