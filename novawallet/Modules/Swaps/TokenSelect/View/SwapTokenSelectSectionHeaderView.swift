import UIKit

final class SwapTokenSelectSectionHeaderView: UITableViewHeaderFooterView {
    let titleLabel: UILabel = .create { view in
        view.apply(style: .semiboldFootnoteSecondary)
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = R.color.colorBottomSheetBackground()
        backgroundConfiguration = background

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview().inset(Constants.topInset)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SwapTokenSelectSectionHeaderView {
    enum Constants {
        static let height: CGFloat = 30
        static let topInset: CGFloat = 9.5
    }
}
