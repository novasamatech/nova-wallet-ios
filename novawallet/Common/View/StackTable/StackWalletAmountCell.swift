import UIKit

final class StackWalletAmountCell: RowView<GenericTitleValueView<WalletTotalAmountView, UIImageView>>,
    StackTableViewCellProtocol {
    var walletView: WalletTotalAmountView { rowContentView.titleView }
    var disclosureIndicatorView: UIImageView { rowContentView.valueView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    convenience init() {
        self.init(frame: CGRect(origin: .zero, size: CGSize(width: 340, height: 44)))
    }

    private func setupStyle() {
        let icon = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
        disclosureIndicatorView.image = icon
    }

    func bind(viewModel: WalletTotalAmountView.ViewModel) {
        walletView.bind(viewModel: viewModel)
    }
}
