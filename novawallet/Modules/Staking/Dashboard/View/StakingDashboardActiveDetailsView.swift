import UIKit

final class StakingDashboardActiveDetailsView: UIView {
    private let internalStatusView: GenericTitleValueView<StakingStatusView, UIImageView> = .create { view in
        view.valueView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorTextSecondary()!)
        view.titleView.backgroundView.apply(style: .chips)
    }

    var statusView: StakingStatusView { internalStatusView.titleView }

    private let internalYourStakeView: GenericMultiValueView<MultilineBalanceView> = .create { view in
        view.valueTop.apply(style: .caption2Secondary)
        view.valueTop.textAlignment = .left
        view.spacing = 2

        view.valueBottom.amountLabel.apply(style: .semiboldFootnotePrimary)
        view.valueBottom.amountLabel.textAlignment = .left

        view.valueBottom.priceLabel.apply(style: .caption2Secondary)
        view.valueBottom.priceLabel.textAlignment = .left
    }

    let estimatedEarningsView: GenericMultiValueView<GenericPairValueView<UILabel, UILabel>> = .create { view in
        view.valueTop.apply(style: .caption2Secondary)
        view.valueTop.textAlignment = .left
        view.spacing = 2

        view.stackView.alignment = .leading
        view.valueBottom.fView.apply(style: .semiboldFootnotePositive)
        view.valueBottom.sView.apply(style: .caption2Secondary)
        view.valueBottom.makeHorizontal()
        view.valueBottom.spacing = 0
        view.valueBottom.stackView.alignment = .bottom
    }

    var estimatedEarningsLabel: UILabel { estimatedEarningsView.valueBottom.fView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(
        stakingStatus: LoadableViewModelState<StakingDashboardEnabledViewModel.Status>,
        stake: LoadableViewModelState<BalanceViewModelProtocol>,
        estimatedEarnings: LoadableViewModelState<String>,
        locale: Locale
    ) {
        if let status = stakingStatus.value {
            statusView.bind(status: status, locale: locale)
        }

        if stakingStatus.isLoading {
            // TODO: Implement loading state
        }

        if let stakeViewModel = stake.value {
            internalYourStakeView.valueBottom.bind(viewModel: stakeViewModel)
        }

        if stake.isLoading {
            // TODO: Implement loading state
        }

        if let estimatedEarnings = estimatedEarnings.value {
            estimatedEarningsLabel.text = estimatedEarnings
        }

        setupStaticLocalization(for: locale)
    }

    func setupStaticLocalization(for locale: Locale) {
        internalYourStakeView.valueTop.text = R.string.localizable.stakingYourStake(
            preferredLanguages: locale.rLanguages
        )

        estimatedEarningsView.valueTop.text = R.string.localizable.stakingEstimatedEarnings(
            preferredLanguages: locale.rLanguages
        )

        estimatedEarningsView.valueBottom.sView.text = R.string.localizable.parachainStakingRewardsFormat(
            "",
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        let contentView = UIView.vStack(
            spacing: 12,
            [
                internalStatusView,
                internalYourStakeView,
                estimatedEarningsView
            ]
        )

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
    }
}
