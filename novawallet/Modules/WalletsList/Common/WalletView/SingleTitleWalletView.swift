import UIKit

class SingleTitleWalletView: GenericTitleValueView<WalletIconView, UILabel>, WalletViewProtocol {
    var viewModel: ViewModel?

    var iconImageView: UIImageView { titleView.iconViewImageView }
    var networkImageView: UIImageView { titleView.networkIconImageView }
    var titleLabel: UILabel { valueView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
    }

    func setupStyle() {
        titleLabel.apply(style: .regularSubhedlinePrimary)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        spacing = 12
        alignment = .left

        titleView.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueView.setContentCompressionResistancePriority(.low, for: .horizontal)
    }

    func cancelProxyIconsLoading(info: WalletView.ViewModel.ProxyInfo?) {
        info?.networkIcon?.cancel(on: networkImageView)
        networkImageView.image = nil

        titleView.clear()
    }

    func bind(regular _: ViewModel.BalanceInfo) {}

    func bind(proxy viewModel: ViewModel.ProxyInfo) {
        viewModel.networkIcon?.loadImage(
            on: networkImageView,
            targetSize: WalletIconView.Constants.networkIconSize,
            animated: true
        )

        networkImageView.isHidden = viewModel.networkIcon == nil

        titleView.setNeedsLayout()
    }
}
