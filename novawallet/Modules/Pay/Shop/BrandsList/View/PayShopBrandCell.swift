import UIKit

final class PayShopBrandCell: BlurredCollectionViewCell<PayShopBrandContentView> {
    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    private func setupStyle() {
        view.contentInsets = .zero
        view.innerInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 14)
    }

    func bind(viewModel: PayShopBrandViewModel, locale: Locale) {
        view.view.bind(viewModel: viewModel, locale: locale)
    }
}

final class PayShopBrandContentView: GenericTitleValueView<
    LoadableIconDetailsView, IconDetailsGenericView<MultiValueView>
> {
    enum Constants {
        static let iconSize: CGFloat = 36
        static let iconDetailsSpacing: CGFloat = 12
        static let horizontalSpacing: CGFloat = 8
        static let cashbackSpacing: CGFloat = 0
        static let indicatorSpacing: CGFloat = 4
        static let indicatorWidth: CGFloat = 24
    }

    var commissionValueLabel: UILabel { valueView.detailsView.valueTop }

    var commissionTitleLabel: UILabel { valueView.detailsView.valueBottom }

    var indicatorView: UIImageView { valueView.imageView }

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    private func configure() {
        titleView.iconWidth = Constants.iconSize
        titleView.spacing = Constants.iconDetailsSpacing
        titleView.detailsLabel.apply(style: .regularSubhedlinePrimary)

        valueView.mode = .detailsIcon
        valueView.spacing = Constants.indicatorSpacing
        valueView.iconWidth = Constants.indicatorWidth
        valueView.detailsView.spacing = Constants.cashbackSpacing

        commissionValueLabel.textAlignment = .right
        commissionValueLabel.apply(style: .semiboldCalloutPositive)

        commissionTitleLabel.textAlignment = .right
        commissionTitleLabel.apply(style: .caption1Secondary)

        spacing = Constants.horizontalSpacing

        indicatorView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorIconSecondary()!)

        valueView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func bind(viewModel: PayShopBrandViewModel, locale: Locale) {
        let titleViewModel = StackCellViewModel(
            details: viewModel.name,
            imageViewModel: viewModel.iconViewModel
        )

        let imageSettings = ImageViewModelSettings(
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            cornerRadius: Constants.iconSize / 2
        )

        titleView.bind(viewModel: titleViewModel, imageSettings: imageSettings)

        let bottomValue = viewModel.commission != nil ? R.string.localizable.commonCashback(
            preferredLanguages: locale.rLanguages
        ) : nil

        valueView.detailsView.bind(
            topValue: viewModel.commission ?? "",
            bottomValue: bottomValue
        )
    }
}
