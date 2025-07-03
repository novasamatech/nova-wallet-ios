import Foundation
import UIKit

final class WalletInfoView<T: WalletViewProtocol>: GenericTitleValueView<T, UIImageView> {
    var walletView: WalletViewProtocol { titleView }
    var infoIndicatorImageView: UIImageView { valueView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }
}

private extension WalletInfoView {
    func setupLayout() {
        infoIndicatorImageView.setContentCompressionResistancePriority(
            .defaultHigh,
            for: .horizontal
        )
    }
}

extension WalletInfoView: WalletViewProtocol {
    var viewModel: ViewModel? {
        get {
            walletView.viewModel
        }
        set {
            walletView.viewModel = newValue
        }
    }

    var iconImageView: UIImageView { walletView.iconImageView }

    var titleLabel: UILabel { walletView.titleLabel }

    var networkImageView: UIImageView { walletView.networkImageView }

    func bind(delegatedAccount viewModel: ViewModel.DelegatedAccountInfo) {
        walletView.bind(delegatedAccount: viewModel)
    }

    func bind(regular viewModel: ViewModel.BalanceInfo) {
        walletView.bind(regular: viewModel)
    }

    func cancelIconsLoading(info: ViewModel.DelegatedAccountInfo?) {
        walletView.cancelIconsLoading(info: info)
    }

    func setAppearance(for selectionAvailable: Bool) {
        walletView.setAppearance(for: selectionAvailable)
    }

    func bindNoInfo() {
        walletView.bindNoInfo()
    }
}
