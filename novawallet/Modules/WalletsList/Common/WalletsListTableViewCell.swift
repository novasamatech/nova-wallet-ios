import UIKit

protocol WalletsListTableViewCellProtocol {
    func bind(viewModel: WalletsListViewModel)
}

class WalletsListTableViewCell<T: WalletViewProtocol, V: UIView>: PlainBaseTableViewCell<
    GenericTitleValueView<T, V>
>, WalletsListTableViewCellProtocol {
    var infoView: WalletViewProtocol { contentDisplayView.titleView }

    override func prepareForReuse() {
        super.prepareForReuse()

        infoView.cancelImagesLoading()
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
        contentDisplayView.spacing = 29
    }

    func bind(viewModel: WalletsListViewModel) {
        infoView.bind(viewModel: viewModel.walletViewModel)
        infoView.setAppearance(for: viewModel.isSelectable)
    }
}
