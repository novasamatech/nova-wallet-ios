import UIKit
import UIKit_iOS

final class StakingDashboardActiveDetailsView: UIView {
    private enum Constants {
        static let statusOffset: CGFloat = 0
        static let stakeOffset: CGFloat = 34
        static let earningsOffset: CGFloat = 94
    }

    private let internalStatusView: GenericTitleValueView<LoadableStakingStatusView, UIImageView> = .create { view in
        view.valueView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorTextSecondary()!)
        view.titleView.backgroundView.apply(style: .chips)
        view.spacing = 4
    }

    var statusView: LoadableStakingStatusView { internalStatusView.titleView }

    private let internalStakeView: GenericMultiValueView<ShimmerSecureMultibalanceView> = .create { view in
        view.valueTop.apply(style: .caption2Secondary)
        view.valueTop.textAlignment = .left
        view.spacing = 2

        view.valueBottom.amountLabel.applyShimmer(style: .semiboldFootnotePrimary)
        view.valueBottom.amountLabel.textAlignment = .left

        view.valueBottom.priceLabel.applyShimmer(style: .caption2Secondary)
        view.valueBottom.priceLabel.textAlignment = .left
    }

    let estimatedEarningsView: GenericMultiValueView<GenericPairValueView<ShimmerLabel, UILabel>> = .create { view in
        view.valueTop.apply(style: .caption2Secondary)
        view.valueTop.textAlignment = .left
        view.spacing = 2

        view.stackView.alignment = .leading
        view.valueBottom.fView.applyShimmer(style: .semiboldFootnotePositive)
        view.valueBottom.sView.apply(style: .caption2Secondary)
        view.valueBottom.makeHorizontal()
        view.valueBottom.spacing = 0
        view.valueBottom.stackView.alignment = .bottom
    }

    var estimatedEarningsLabel: ShimmerLabel { estimatedEarningsView.valueBottom.fView }

    var skeletonView: SkrullableView?

    private(set) var loadingState: LoadingState = .none

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if loadingState != .none {
            updateLoadingState()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(
        stakingStatus: LoadableViewModelState<StakingDashboardEnabledViewModel.Status>,
        stake: SecuredViewModel<LoadableViewModelState<BalanceViewModelProtocol>>,
        estimatedEarnings: LoadableViewModelState<String?>,
        locale: Locale
    ) {
        stopLoadingIfNeeded()

        var newLoadingState: LoadingState = .none

        statusView.stopLoadingIfNeeded()

        switch stakingStatus {
        case .loading:
            newLoadingState.formUnion(.status)
        case let .cached(value):
            statusView.bind(status: value, locale: locale)
            statusView.startLoadingIfNeeded()
        case let .loaded(value):
            statusView.bind(status: value, locale: locale)
        }

        internalStakeView.valueBottom.bind(viewModel: stake)

        if stake.originalContent.isLoading {
            newLoadingState.formUnion(.stake)
        }

        estimatedEarningsLabel.bind(viewModel: estimatedEarnings.map(with: { $0 ?? "" }))

        if estimatedEarnings.isLoading {
            newLoadingState.formUnion(.earnings)
        }

        let hasEstimatedRewards = estimatedEarnings.isLoading || estimatedEarnings.satisfies { $0 != nil }
        setupStaticLocalization(for: locale, hasEstimatedRewards: hasEstimatedRewards)

        loadingState = newLoadingState

        if loadingState != .none {
            startLoadingIfNeeded()
        }
    }

    func bindLoadingState() {
        stopLoadingIfNeeded()

        loadingState = .all

        startLoadingIfNeeded()
    }

    func updateLoadingAnimationIfActive() {
        if loadingState != .none {
            updateLoadingState()

            skeletonView?.restartSkrulling()
        }

        statusView.updateLoadingAnimationIfActive()
        internalStakeView.valueBottom.updateLoadingAnimationIfActive()
        estimatedEarningsLabel.updateShimmeringIfActive()
    }

    private func setupStaticLocalization(for locale: Locale, hasEstimatedRewards: Bool) {
        internalStakeView.valueTop.text = R.string.localizable.stakingYourStake(
            preferredLanguages: locale.rLanguages
        )

        if hasEstimatedRewards {
            estimatedEarningsView.valueTop.text = R.string.localizable.stakingEstimatedEarnings(
                preferredLanguages: locale.rLanguages
            )

            estimatedEarningsView.valueBottom.sView.text = " " + R.string.localizable.commonPerYear(
                preferredLanguages: locale.rLanguages
            )
        } else {
            estimatedEarningsView.valueTop.text = ""
            estimatedEarningsView.valueBottom.sView.text = ""
        }
    }

    private func setupLayout() {
        addSubview(internalStatusView)
        internalStatusView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.statusOffset)
            make.height.equalTo(22)
        }

        addSubview(internalStakeView)
        internalStakeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.stakeOffset)
        }

        internalStakeView.valueBottom.amountSecureView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(18)
        }
        internalStakeView.valueBottom.priceSecureView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(13)
        }

        addSubview(estimatedEarningsView)
        estimatedEarningsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.earningsOffset)
        }
    }
}

extension StakingDashboardActiveDetailsView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        if loadingState == .all {
            return [
                internalStatusView,
                internalStakeView,
                estimatedEarningsView
            ]
        }

        var hidingViews: [UIView] = []

        if loadingState.contains(.status) {
            hidingViews.append(statusView)
        }

        if loadingState.contains(.stake) {
            hidingViews.append(internalStakeView.valueBottom)
        }

        if loadingState.contains(.earnings) {
            hidingViews.append(estimatedEarningsView.valueBottom)
        }

        return hidingViews
    }

    // swiftlint:disable:next function_body_length
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        var skeletons: [Skeletonable] = []

        if loadingState.contains(.status) {
            skeletons.append(
                SingleSkeleton.createRow(
                    on: self,
                    containerView: self,
                    spaceSize: spaceSize,
                    offset: CGPoint(x: 0, y: Constants.statusOffset + 6),
                    size: CGSize(width: 44, height: 10)
                )
            )
        }

        if loadingState.contains(.stake) {
            if loadingState == .all {
                skeletons.append(
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0, y: Constants.stakeOffset + 2),
                        size: CGSize(width: 44, height: 8)
                    )
                )
            }

            skeletons.append(
                contentsOf: [
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0, y: Constants.stakeOffset + 19),
                        size: CGSize(width: 64, height: 10)
                    ),
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0, y: Constants.stakeOffset + 37),
                        size: CGSize(width: 53, height: 8)
                    )
                ]
            )
        }

        if loadingState.contains(.earnings) {
            if loadingState == .all {
                skeletons.append(
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0, y: Constants.earningsOffset + 4),
                        size: CGSize(width: 53, height: 8)
                    )
                )
            }

            skeletons.append(
                SingleSkeleton.createRow(
                    on: self,
                    containerView: self,
                    spaceSize: spaceSize,
                    offset: CGPoint(x: 0, y: Constants.earningsOffset + 20),
                    size: CGSize(width: 41, height: 8)
                )
            )
        }

        return skeletons
    }
}

extension StakingDashboardActiveDetailsView {
    struct LoadingState: OptionSet {
        typealias RawValue = UInt8

        static let status = LoadingState(rawValue: 1 << 0)
        static let stake = LoadingState(rawValue: 1 << 1)
        static let earnings = LoadingState(rawValue: 1 << 2)
        static let all: LoadingState = [.status, .stake, .earnings]
        static let none: LoadingState = []

        let rawValue: UInt8

        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}
