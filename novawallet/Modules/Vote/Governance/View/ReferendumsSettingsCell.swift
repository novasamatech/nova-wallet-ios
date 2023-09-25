import UIKit

final class ReferendumsSettingsCell: UITableViewCell {
    let titleLabel: UILabel = .create {
        $0.font = .semiBoldTitle3
        $0.textColor = R.color.colorTextPrimary()
    }

    let searchButton: TriangularedBlurButton = .create {
        $0.imageWithTitleView?.iconImage = R.image.iconSearchButton()
        $0.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        $0.changesContentOpacityWhenHighlighted = true
        $0.triangularedBlurView?.overlayView?.highlightedFillColor =
            R.color.colorCellBackgroundPressed()!
    }

    let filterButton = FilterBlurButton()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(filterButton)

        filterButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(searchButton)

        searchButton.snp.makeConstraints { make in
            make.trailing.equalTo(filterButton.snp.leading).inset(-8)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualTo(searchButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    func bind(title: String?, isFilterOn: Bool) {
        titleLabel.text = title
        filterButton.bind(isFilterOn: isFilterOn)
    }
}
