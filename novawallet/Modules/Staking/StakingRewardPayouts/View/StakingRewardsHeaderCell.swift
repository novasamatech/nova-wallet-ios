import UIKit

final class StakingRewardsHeaderCell: UITableViewCell {
    let bannerView: GradientBannerView = {
        let view = GradientBannerView()
        view.infoView.imageView.image = R.image.iconBannerCalendar()
        view.bind(model: .stakingUnpaidRewards())
        view.showsLink = false
        view.contentInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 28.0, right: 0.0)
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        selectionStyle = .none

        setupLayout()
        applyLocalization()
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyLocalization() {
        bannerView.infoView.titleLabel.text = R.string.localizable.stakingPendingRewardsHintTitle(
            preferredLanguages: locale.rLanguages
        )

        bannerView.infoView.subtitleLabel.text = R.string.localizable.stakingPendingRewardsHintMessage(
            preferredLanguages: locale.rLanguages
        )
    }

    func setupLayout() {
        contentView.addSubview(bannerView)
        bannerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(16.0)
        }
    }
}
