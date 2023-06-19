import UIKit
import SoraUI

final class StakingDashboardActiveDetailsView: UIView {
    private enum Constants {
        static let statusOffset: CGFloat = 6
        static let stakeOffset: CGFloat = 36
        static let earningsOffset: CGFloat = 97
    }

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

    var skeletonView: SkrullableView?

    private(set) var loadingState: LoadingState = .none

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

        var newLoadingState: LoadingState = .none

        if stakingStatus.isLoading {
            newLoadingState.formUnion(.status)
        }

        if let stakeViewModel = stake.value {
            internalYourStakeView.valueBottom.bind(viewModel: stakeViewModel)
        }

        if stake.isLoading {
            newLoadingState.formUnion(.stake)
        }

        estimatedEarningsLabel.text = estimatedEarnings.value

        if estimatedEarnings.isLoading {
            newLoadingState.formUnion(.earnings)
        }

        stopLoadingIfNeeded()

        setupStaticLocalization(for: locale)

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
        addSubview(internalStatusView)
        internalStatusView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.statusOffset)
        }

        addSubview(internalYourStakeView)
        internalYourStakeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().inset(Constants.stakeOffset)
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
                internalYourStakeView,
                estimatedEarningsView
            ]
        }

        var hidingViews: [UIView] = []

        if loadingState.contains(.status) {
            hidingViews.append(statusView)
        }

        if loadingState.contains(.stake) {
            hidingViews.append(internalYourStakeView.valueBottom)
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
                    offset: CGPoint(x: 0, y: Constants.statusOffset),
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
                        offset: CGPoint(x: 0, y: Constants.stakeOffset),
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
                        offset: CGPoint(x: 0, y: Constants.stakeOffset + 17),
                        size: CGSize(width: 64, height: 10)
                    ),
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0, y: Constants.stakeOffset + 35),
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
                        offset: CGPoint(x: 0, y: Constants.earningsOffset),
                        size: CGSize(width: 53, height: 8)
                    )
                )
            }

            skeletons.append(
                SingleSkeleton.createRow(
                    on: self,
                    containerView: self,
                    spaceSize: spaceSize,
                    offset: CGPoint(x: 0, y: Constants.earningsOffset + 16),
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
