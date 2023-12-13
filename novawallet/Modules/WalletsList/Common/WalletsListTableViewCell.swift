import UIKit

protocol WalletsListTableViewCellProtocol {
    func bind(viewModel: WalletsListViewModel)
}

class WalletsListTableViewCell<V: UIView>: PlainBaseTableViewCell<
    GenericTitleValueView<WalletView, V>
>, WalletsListTableViewCellProtocol {
    var infoView: WalletView { contentDisplayView.titleView }

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
    }
}
