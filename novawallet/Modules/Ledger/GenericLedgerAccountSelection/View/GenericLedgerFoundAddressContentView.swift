import UIKit

final class GenericLedgerFoundAddressContentView: GenericTitleValueView<
    UILabel, IconDetailsGenericView<LoadableIconDetailsView>
> {
    var titleLabel: UILabel { titleView }
    var addressLabel: UILabel { valueView.detailsView.detailsLabel }
    var indicatorView: UIImageView { valueView.imageView }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44.0)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configure()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        spacing = 16

        titleLabel.apply(style: .footnoteSecondary)

        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        addressLabel.apply(style: .footnotePrimary)
        addressLabel.numberOfLines = 1
        addressLabel.lineBreakMode = .byTruncatingMiddle

        addressLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        valueView.mode = .detailsIcon
        valueView.iconWidth = 16
        valueView.spacing = 8

        valueView.detailsView.mode = .iconDetails
        valueView.detailsView.iconWidth = 20
        valueView.detailsView.spacing = 8

        indicatorView.image = R.image.iconInfoFilled()
    }

    func bind(viewModel: GenericLedgerFoundAddressContentView.ViewModel) {
        titleLabel.text = viewModel.title

        valueView.detailsView.bind(viewModel: viewModel.accessoryViewModel)
    }
}

extension GenericLedgerFoundAddressContentView {
    struct ViewModel {
        let title: String
        let accessoryViewModel: StackCellViewModel
    }
}
