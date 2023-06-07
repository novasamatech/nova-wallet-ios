import UIKit

final class StakingDashboardInactiveCell: BlurredCollectionViewCell<StakingDashboardInactiveCellView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        view.innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 12)
    }
}

final class StakingDashboardInactiveCellView: GenericTitleValueView<
    LoadableIconDetailsView, IconDetailsGenericView<MultiValueView>
> {
    private enum Constants {
        static let iconSize = CGSize(width: 36, height: 36)
    }

    var networkNameLabel: UILabel { titleView.detailsLabel }
    var estimatedEarningsLabel: UILabel { valueView.detailsView.valueTop }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    func bind(viewModel: StakingDashboardDisabledViewModel, locale: Locale) {
        titleView.bind(viewModel: viewModel.networkViewModel.cellViewModel)
        estimatedEarningsLabel.text = viewModel.estimatedEarnings.value

        if viewModel.estimatedEarnings.isLoading {
            // TODO: implement loading state
        }

        setupStaticLocalization(for: locale)
    }

    func setupStaticLocalization(for locale: Locale) {
        valueView.detailsView.valueBottom.text = R.string.localizable.parachainStakingRewardsFormat(
            "",
            preferredLanguages: locale.rLanguages
        )
    }

    private func configure() {
        titleView.iconWidth = Constants.iconSize.width
        titleView.spacing = 12

        networkNameLabel.apply(style: .regularSubhedlinePrimary)
        networkNameLabel.numberOfLines = 1

        valueView.detailsView.valueTop.apply(style: .semiboldCalloutPositive)
        valueView.detailsView.valueBottom.apply(style: .caption1Secondary)
        valueView.spacing = 8

        valueView.iconWidth = 16
        valueView.imageView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
    }
}
