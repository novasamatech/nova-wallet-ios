import UIKit

protocol WalletViewProtocol: UIView {
    typealias ViewModel = WalletView.ViewModel

    var iconContainerView: WalletIconView { get }
    var iconImageView: UIImageView { get }
    var titleLabel: UILabel { get }
    var networkImageView: UIImageView { get }
    var iconTitleSpacing: CGFloat { get set }
    var viewModel: ViewModel? { get set }
    func cancelIconsLoading(info: ViewModel.DelegatedAccountInfo?)
    func setAppearance(for selectionAvailable: Bool)
    func bind(regular viewModel: ViewModel.BalanceInfo)
    func bind(delegatedAccount viewModel: ViewModel.DelegatedAccountInfo)
    func bind(chainAccount viewModel: ViewModel.ChainAccountAddressInfo)
    func bindNoInfo()
}

extension WalletViewProtocol {
    func bind(viewModel: ViewModel) {
        bind(wallet: viewModel.wallet)

        switch viewModel.type {
        case let .regular(balanceViewModel):
            bind(regular: balanceViewModel)
        case let .proxy(delegatedAccountViewModel), let .multisig(delegatedAccountViewModel):
            bind(delegatedAccount: delegatedAccountViewModel)
        case let .account(accountViewModel):
            bind(chainAccount: accountViewModel)
        case .noInfo:
            bindNoInfo()
        }

        self.viewModel = viewModel
    }

    func cancelImagesLoading() {
        cancelIconLoading(info: viewModel?.wallet)
        cancelIconsLoading(info: viewModel?.delegatedAccountInfo)
    }
}

private extension WalletViewProtocol {
    private func cancelIconLoading(info: ViewModel.WalletInfo?) {
        info?.icon?.cancel(on: iconImageView)
        iconImageView.image = nil
    }

    private func bind(wallet viewModel: ViewModel.WalletInfo) {
        cancelImagesLoading()

        viewModel.icon?.loadImage(
            on: iconImageView,
            targetSize: WalletIconView.Constants.iconSize,
            animated: true
        )
        titleLabel.text = viewModel.name
    }
}
