import UIKit

protocol WalletsListTableViewCellProtocol {
    func bind(viewModel: WalletsListViewModel)
}

class WalletsListTableViewCell<V: UIView>: PlainBaseTableViewCell<
    GenericTitleValueView<WalletTotalAmountView, V>
>, WalletsListTableViewCellProtocol {
    var infoView: WalletTotalAmountView { contentDisplayView.titleView }

    override func prepareForReuse() {
        super.prepareForReuse()

        infoView.cancelImageLoading()
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }

    func bind(viewModel: WalletsListViewModel) {
        infoView.bind(viewModel: viewModel.walletAmountViewModel)
    }
}
