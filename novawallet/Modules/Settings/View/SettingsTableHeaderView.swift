import UIKit

final class SettingsTableHeaderView: UIView {
    enum Constants {
        static let topOffset: CGFloat = 12
        static let cellHeight: CGFloat = 56

        static var totalHeight: CGFloat {
            topOffset + cellHeight
        }
    }

    let accountDetailsView: DetailsTriangularedView = {
        let detailsView = DetailsTriangularedView()
        detailsView.layout = .singleTitle
        detailsView.iconRadius = UIConstants.normalAddressIconSize.height / 2.0
        detailsView.titleLabel.lineBreakMode = .byTruncatingTail
        detailsView.titleLabel.font = .regularSubheadline
        detailsView.titleLabel.textColor = R.color.colorTextPrimary()
        detailsView.actionImage = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
        detailsView.fillColor = R.color.colorBlockBackground()!
        detailsView.highlightedFillColor = R.color.colorCellBackgroundPressed()!
        detailsView.horizontalSpacing = 12.0
        detailsView.contentInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return detailsView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(accountDetailsView)
        accountDetailsView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(Constants.topOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(Constants.cellHeight)
        }
    }
}
