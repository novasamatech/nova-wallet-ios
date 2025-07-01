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

    func cancelIconsLoading(info: WalletView.ViewModel.DelegatedAccountInfo?) {
        info?.networkIcon?.cancel(on: networkImageView)
        networkImageView.image = nil

        titleView.clear()
    }

    func bind(regular _: ViewModel.BalanceInfo) {
        networkImageView.isHidden = true
    }

    func bindNoInfo() {
        networkImageView.isHidden = true
    }

    func bind(delegatedAccount viewModel: ViewModel.DelegatedAccountInfo) {
        viewModel.networkIcon?.loadImage(
            on: networkImageView,
            targetSize: WalletIconView.Constants.networkIconSize,
            animated: true
        )

        networkImageView.isHidden = viewModel.networkIcon == nil

        titleView.setNeedsLayout()
    }

    func setAppearance(for selectionAvailable: Bool) {
        if selectionAvailable {
            titleLabel.textColor = R.color.colorTextPrimary()
        } else {
            titleLabel.textColor = R.color.colorTextSecondary()
        }

        let alpha = selectionAvailable ? 1.0 : 0.5

        [
            networkImageView,
            iconImageView
        ].forEach { $0.alpha = alpha }
    }
}
