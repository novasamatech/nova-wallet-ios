import UIKit

protocol WalletViewProtocol: UIView {
    typealias ViewModel = WalletView.ViewModel

    var iconImageView: UIImageView { get }
    var titleLabel: UILabel { get }
    var networkImageView: UIImageView { get }
    var viewModel: ViewModel? { get set }
    func cancelProxyIconsLoading(info: ViewModel.ProxyInfo?)
    func bind(regular viewModel: ViewModel.BalanceInfo)
    func bind(proxy viewModel: ViewModel.ProxyInfo)
}

extension WalletViewProtocol {
    func bind(viewModel: ViewModel) {
        bind(wallet: viewModel.wallet)

        switch viewModel.type {
        case let .regular(balanceViewModel):
            bind(regular: balanceViewModel)
        case let .proxy(proxyViewModel):
            bind(proxy: proxyViewModel)
        case .noInfo:
            break
        }

        self.viewModel = viewModel
    }

    func cancelImagesLoading() {
        cancelIconLoading(info: viewModel?.wallet)
        cancelProxyIconsLoading(info: viewModel?.proxyInfo)
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
