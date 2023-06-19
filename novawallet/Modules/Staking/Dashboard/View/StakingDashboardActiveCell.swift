import UIKit
import SoraUI

typealias StakingDashboardActiveCell = BlurredCollectionViewCell<StakingDashboardActiveCellView>

final class StakingDashboardActiveCellView: UIView {
    private enum Constants {
        static let leadingOffset = 16
        static let topOffset = 16
    }

    let networkView = LoadableAssetListChainView()

    let detailsView: BlurredView<StakingDashboardActiveDetailsView> = .create { view in
        view.contentInsets = .zero
        view.innerInsets = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        view.backgroundBlurView.contentView?.fillColor = R.color.colorInfoStakingCardBackground()!
    }

    let rewardsView: GenericMultiValueView<MultilineBalanceView> = .create { view in
        view.valueTop.apply(style: .footnoteSecondary)
        view.valueTop.textAlignment = .left

        view.valueBottom.amountLabel.apply(style: .boldTitle2Primary)
        view.valueBottom.amountLabel.textAlignment = .left

        view.valueBottom.priceLabel.apply(style: .regularSubhedlineSecondary)
        view.valueBottom.priceLabel.textAlignment = .left
    }

    var skeletonView: SkrullableView?

    private var loadingState: LoadingState = .none

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: StakingDashboardEnabledViewModel, locale: Locale) {
        var newLoadingState: LoadingState = .none

        networkView.stopLoadingIfNeeded()

        switch viewModel.networkViewModel {
        case .loading:
            newLoadingState.formUnion(.network)
        case let .cached(value):
            networkView.bind(viewModel: value)
            networkView.startLoadingIfNeeded()
        case let .loaded(value):
            networkView.bind(viewModel: value)
        }

        if let value = viewModel.totalRewards.value {
            rewardsView.valueBottom.bind(viewModel: value)
        }

        if viewModel.totalRewards.isLoading {
            newLoadingState.formUnion(.rewards)
        }

        detailsView.view.bind(
            stakingStatus: viewModel.status,
            stake: viewModel.yourStake,
            estimatedEarnings: viewModel.estimatedEarnings,
            locale: locale
        )

        setupStaticLocalization(for: locale)

        stopLoadingIfNeeded()

        loadingState = newLoadingState

        if loadingState != .none {
            startLoadingIfNeeded()
        }
    }

    func bindLoadingState() {
        stopLoadingIfNeeded()

        detailsView.view.bindLoadingState()

        loadingState = .all

        startLoadingIfNeeded()
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
            make.leading.equalToSuperview().inset(Constants.leadingOffset)
            make.top.equalToSuperview().inset(Constants.topOffset)
            make.trailing.lessThanOrEqualTo(detailsView.snp.leading).offset(-8)
        }

        addSubview(rewardsView)
        rewardsView.snp.makeConstraints { make in
            make.top.equalTo(networkView.snp.bottom).offset(24)
            make.leading.equalToSuperview().inset(Constants.leadingOffset)
            make.trailing.lessThanOrEqualTo(detailsView.snp.leading).offset(-8)
        }
    }
}

extension StakingDashboardActiveCellView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        if loadingState == .all {
            return [
                networkView,
                rewardsView
            ]
        }

        var hidingViews: [UIView] = []

        if loadingState.contains(.network) {
            hidingViews.append(networkView)
        }

        if loadingState.contains(.rewards) {
            hidingViews.append(rewardsView.valueBottom)
        }

        return hidingViews
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        var skeletons: [Skeletonable] = []

        if loadingState.contains(.network) {
            skeletons.append(
                SingleSkeleton.createRow(
                    on: self,
                    containerView: self,
                    spaceSize: spaceSize,
                    offset: CGPoint(x: Constants.leadingOffset, y: Constants.topOffset),
                    size: CGSize(width: 78, height: 20),
                    cornerRadii: CGSize(width: 0.2, height: 0.2)
                )
            )
        }

        if loadingState.contains(.rewards) {
            if loadingState == .all {
                skeletons.append(
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: Constants.leadingOffset, y: 67),
                        size: CGSize(width: 49, height: 10)
                    )
                )
            }

            skeletons.append(
                contentsOf: [
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: Constants.leadingOffset, y: 91),
                        size: CGSize(width: 129, height: 16)
                    ),
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: Constants.leadingOffset, y: 121),
                        size: CGSize(width: 56, height: 10)
                    )
                ]
            )
        }

        return skeletons
    }
}

extension StakingDashboardActiveCellView {
    struct LoadingState: OptionSet {
        typealias RawValue = UInt8

        static let network = LoadingState(rawValue: 1 << 0)
        static let rewards = LoadingState(rawValue: 1 << 1)
        static let all: LoadingState = [.network, .rewards]
        static let none: LoadingState = []

        let rawValue: UInt8

        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}
