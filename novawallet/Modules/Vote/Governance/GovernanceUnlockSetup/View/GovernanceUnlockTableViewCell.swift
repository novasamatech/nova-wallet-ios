import UIKit

final class GovernanceUnlockTableViewCell: UITableViewCell {
    private let lockView = GenericTitleValueView<UILabel, IconDetailsView>()

    var amountLabel: UILabel { lockView.titleView }
    var detailsLabel: UILabel { lockView.valueView.detailsLabel }
    var iconImageView: UIImageView { lockView.valueView.imageView }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: GovernanceUnlocksViewModel.Item, locale: Locale) {
        amountLabel.text = viewModel.amount

        bind(claimState: viewModel.claimState, locale: locale)
    }

    func bind(claimState: GovernanceUnlocksViewModel.ClaimState, locale: Locale) {
        switch claimState {
        case let .afterPeriod(time):
            lockView.valueView.hidesIcon = false
            detailsLabel.textColor = R.color.colorTransparentText()
            detailsLabel.text = time
        case .now:
            lockView.valueView.hidesIcon = true
            detailsLabel.textColor = R.color.colorGreen()
            detailsLabel.text = R.string.localizable.commonUnlockable(preferredLanguages: locale.rLanguages)
        }
    }

    private func applyStyle() {
        backgroundColor = .clear

        amountLabel.apply(style: .regularSubhedlineWhite)

        detailsLabel.font = .caption1
        detailsLabel.numberOfLines = 1
        lockView.valueView.spacing = 4
        iconImageView.image = R.image.iconPending()

        lockView.valueView.mode = .detailsIcon
    }

    private func setupLayout() {
        addSubview(lockView)
        lockView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
            make.height.equalTo(40)
        }
    }
}
