import UIKit

typealias StakingDashboardActiveCell = BlurredCollectionViewCell<StakingDashboardActiveCellView>

final class StakingDashboardActiveCellView: UIView {
    let networkView = AssetListChainView()

    let detailsView: BlurredView<StakingDashboardActiveDetailsView> = .create { view in
        view.contentInsets = .zero
        view.innerInsets = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
    }

    let rewardsView: GenericMultiValueView<MultilineBalanceView> = .create { view in
        view.valueTop.apply(style: .footnoteSecondary)
        view.valueTop.textAlignment = .left

        view.valueBottom.amountLabel.apply(style: .boldTitle2Primary)
        view.valueBottom.amountLabel.textAlignment = .left

        view.valueBottom.priceLabel.apply(style: .regularSubhedlineSecondary)
        view.valueBottom.priceLabel.textAlignment = .left
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: StakingDashboardEnabledViewModel, locale: Locale) {
        networkView.bind(viewModel: viewModel.networkViewModel)

        if let value = viewModel.totalRewards.value {
            rewardsView.valueBottom.bind(viewModel: value)
        }

        if viewModel.totalRewards.isLoading {
            // TODO: Show loading state
        }

        detailsView.view.bind(
            stakingStatus: viewModel.status,
            stake: viewModel.yourStake,
            estimatedEarnings: viewModel.estimatedEarnings,
            locale: locale
        )

        setupStaticLocalization(for: locale)
    }

    private func setupStaticLocalization(for locale: Locale) {
        rewardsView.valueTop.text = R.string.localizable.stakingRewardsTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(detailsView)

        detailsView.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview().inset(4)
            make.width.equalTo(130)
        }

        addSubview(networkView)

        networkView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(16)
            make.trailing.lessThanOrEqualTo(detailsView.snp.leading).offset(-8)
        }

        addSubview(rewardsView)
        rewardsView.snp.makeConstraints { make in
            make.top.equalTo(networkView.snp.bottom).offset(24)
            make.leading.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(24)
            make.trailing.lessThanOrEqualTo(detailsView.snp.leading).offset(-8)
        }
    }
}
