import UIKit

final class ValidatorListFilterSortCell: UITableViewCell {
    let selectionView = RadioSelectorView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
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
    }

    private func setupLayout() {
        contentView.addSubview(selectionView)
        selectionView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(selectionView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }
    }

    func bind(viewModel: SelectableViewModel<TitleWithSubtitleViewModel>) {
        titleLabel.text = viewModel.underlyingViewModel.title
        selectionView.selected = viewModel.selectable
    }
}
