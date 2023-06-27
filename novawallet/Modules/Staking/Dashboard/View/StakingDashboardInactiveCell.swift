import UIKit
import SoraUI

final class StakingDashboardInactiveCell: BlurredCollectionViewCell<StakingDashboardInactiveCellView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        view.innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 12)
    }
}

final class StakingDashboardInactiveCellView: GenericTitleValueView<
    LoadableGenericIconDetailsView<GenericPairValueView<ShimmerLabel, UILabel>>,
    IconDetailsGenericView<GenericPairValueView<ShimmerLabel, UILabel>>
> {
    private enum Constants {
        static let iconSize = CGSize(width: 36, height: 36)
    }

    var networkLabel: ShimmerLabel { titleView.detailsView.fView }
    var balanceLabel: UILabel { titleView.detailsView.sView }
    var estimatedEarningsView: UIView { valueView.detailsView }
    var estimatedEarningsLabel: ShimmerLabel { valueView.detailsView.fView }

    var skeletonView: SkrullableView?

    private var loadingState: LoadingState = .none

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if loadingState != .none {
            updateLoadingState()
        }
    }

    func bind(viewModel: StakingDashboardDisabledViewModel, locale: Locale) {
        stopLoadingIfNeeded()

        var newLoadingState: LoadingState = .none

        if applyNetworkViewModel(from: viewModel, locale: locale) {
            newLoadingState.formUnion(.network)
        }

        estimatedEarningsLabel.bind(viewModel: viewModel.estimatedEarnings.map(with: { $0 ?? "" }))

        if viewModel.estimatedEarnings.isLoading {
            newLoadingState.formUnion(.earnings)
        }

        let hasEstimatedRewards = viewModel.estimatedEarnings.isLoading ||
            viewModel.estimatedEarnings.satisfies { $0 != nil }
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

    private func setupStaticLocalization(for locale: Locale, hasEstimatedRewards: Bool) {
        if hasEstimatedRewards {
            valueView.detailsView.sView.text = R.string.localizable.commonPerYearLong(
                preferredLanguages: locale.rLanguages
            )
        } else {
            valueView.detailsView.sView.text = ""
        }
    }

    private func applyNetworkViewModel(
        from model: StakingDashboardDisabledViewModel,
        locale: Locale
    ) -> Bool {
        networkLabel.stopShimmering()
        titleView.imageView.stopShimmeringOpacity()

        switch model.networkViewModel {
        case .loading:
            titleView.bind(imageViewModel: nil)
            return true
        case let .cached(value):
            setupNetworkView(from: value, balance: model.balance, locale: locale)
            networkLabel.startShimmering()
            titleView.imageView.startShimmeringOpacity()

            return false
        case let .loaded(value):
            setupNetworkView(from: value, balance: model.balance, locale: locale)

            return false
        }
    }

    private func setupNetworkView(from viewModel: NetworkViewModel, balance: String?, locale: Locale) {
        titleView.bind(imageViewModel: viewModel.icon)

        let balanceString = balance.map {
            R.string.localizable.commonAvailableFormat($0, preferredLanguages: locale.rLanguages)
        }

        titleView.detailsView.fView.text = viewModel.name
        titleView.detailsView.sView.text = balanceString
    }

    private func configure() {
        titleView.iconWidth = Constants.iconSize.width
        titleView.spacing = 12

        titleView.detailsView.makeVertical()
        titleView.detailsView.spacing = 0

        networkLabel.applyShimmer(style: .regularSubheadlinePrimary)
        networkLabel.textAlignment = .left

        balanceLabel.apply(style: .caption1Secondary)
        balanceLabel.textAlignment = .left

        valueView.detailsView.makeVertical()
        valueView.spacing = 0

        valueView.detailsView.fView.applyShimmer(style: .semiboldCalloutPositive)
        valueView.detailsView.fView.textAlignment = .right

        valueView.detailsView.sView.apply(style: .caption1Secondary)
        valueView.detailsView.sView.textAlignment = .right

        valueView.mode = .detailsIcon
        valueView.spacing = 8

        valueView.iconWidth = 16
        valueView.imageView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)

        valueView.detailsView.fView.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueView.detailsView.sView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}

extension StakingDashboardInactiveCellView: SkeletonableView {
    var skeletonSuperview: UIView {
        self
    }

    var hidingViews: [UIView] {
        var hidingViews: [UIView] = []

        if loadingState.contains(.network) {
            hidingViews.append(titleView)
        }

        if loadingState.contains(.earnings) {
            hidingViews.append(valueView)
        }

        return hidingViews
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        var skeletons: [Skeletonable] = []

        if loadingState.contains(.network) {
            skeletons.append(
                contentsOf: [
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 0, y: 14),
                        size: CGSize(width: 38, height: 38),
                        cornerRadii: CGSize(width: 12.0 / 38.0, height: 12.0 / 38.0)
                    ),

                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: 48, y: 26),
                        size: CGSize(width: 73, height: 12)
                    )
                ]
            )
        }

        if loadingState.contains(.earnings) {
            skeletons.append(
                contentsOf: [
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: spaceSize.width - 61, y: 18),
                        size: CGSize(width: 57, height: 12)
                    ),
                    SingleSkeleton.createRow(
                        on: self,
                        containerView: self,
                        spaceSize: spaceSize,
                        offset: CGPoint(x: spaceSize.width - 53, y: 38),
                        size: CGSize(width: 49, height: 8)
                    )
                ]
            )
        }

        return skeletons
    }
}

extension StakingDashboardInactiveCellView: LoadingUpdatibleView {
    func updateLoadingAnimationIfActive() {
        if loadingState != .none {
            updateLoadingState()

            skeletonView?.restartSkrulling()
        }

        networkLabel.updateShimmeringIfActive()
        estimatedEarningsLabel.updateShimmeringIfActive()
    }
}

extension StakingDashboardInactiveCellView {
    struct LoadingState: OptionSet {
        typealias RawValue = UInt8

        static let network = LoadingState(rawValue: 1 << 0)
        static let earnings = LoadingState(rawValue: 1 << 1)
        static let all: LoadingState = [.network, .earnings]
        static let none: LoadingState = []

        let rawValue: UInt8

        init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}
