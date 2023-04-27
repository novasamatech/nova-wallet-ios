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

    let filterButton: TriangularedBlurButton = .create {
        $0.imageWithTitleView?.iconImage = R.image.iconFilterAssets()
        $0.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        $0.changesContentOpacityWhenHighlighted = true
        $0.triangularedBlurView?.overlayView?.highlightedFillColor =
            R.color.colorCellBackgroundPressed()!
    }

    let badgeView: UIView = .create {
        $0.backgroundColor = R.color.colorIconAccent()
        $0.clipsToBounds = true
        $0.layer.cornerRadius = 3
        $0.isHidden = true
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(filterButton)

        filterButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        addSubview(badgeView)

        badgeView.snp.makeConstraints { make in
            make.trailing.equalTo(filterButton.snp.trailing).offset(-12)
            make.top.equalTo(filterButton.snp.top).offset(6)
            make.size.equalTo(6)
        }

        addSubview(searchButton)

        searchButton.snp.makeConstraints { make in
            make.trailing.equalTo(filterButton.snp.leading).inset(-8)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.lessThanOrEqualTo(searchButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
    }

    func bind(title: String?, isFilterOn: Bool) {
        titleLabel.text = title
        badgeView.isHidden = !isFilterOn
    }
}
