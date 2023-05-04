import UIKit

typealias WalletConnectSessionCellContent = GenericTitleValueView<
    GenericPairValueView<DAppIconView, GenericMultiValueView<LoadableIconDetailsView>>,
    UIImageView
>

final class WalletConnectSessionCell: PlainBaseTableViewCell<WalletConnectSessionCellContent> {
    var iconView: DAppIconView {
        contentDisplayView.titleView.fView
    }

    var titleLabel: UILabel {
        contentDisplayView.titleView.sView.valueTop
    }

    var walletView: LoadableIconDetailsView {
        contentDisplayView.titleView.sView.valueBottom
    }

    var accessoryImageView: UIImageView {
        contentDisplayView.valueView
    }

    override func setupStyle() {
        super.setupStyle()

        iconView.contentInsets = DAppIconCellConstants.insets

        contentDisplayView.titleView.setHorizontalAndSpacing(12)
        contentDisplayView.titleView.stackView.alignment = .center

        titleLabel.apply(style: .regularSubhedlinePrimary)

        contentDisplayView.titleView.sView.spacing = 2.0

        walletView.iconWidth = 16
        walletView.spacing = 8
        walletView.detailsLabel.numberOfLines = 1
        walletView.detailsLabel.apply(style: .caption1Secondary)

        accessoryImageView.image = R.image.iconChevronRight()?.tinted(with: R.color.colorIconSecondary()!)
    }

    override func setupLayout() {
        super.setupLayout()

        iconView.snp.makeConstraints { make in
            make.size.equalTo(DAppIconCellConstants.size)
        }
    }

    func bind(viewModel: WalletConnectSessionListViewModel) {
        iconView.bind(viewModel: viewModel.iconViewModel, size: DAppIconCellConstants.displaySize)

        titleLabel.text = viewModel.title

        walletView.bind(viewModel: viewModel.wallet?.cellViewModel)
    }
}
