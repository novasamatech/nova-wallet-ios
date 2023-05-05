import Foundation

extension StackInfoTableCell {
    func bindNetworks(viewModel: WalletConnectNetworksViewModel, locale: Locale) {
        titleLabel.text = R.string.localizable.commonNetworksTitle(
            viewModel.totalNetworks,
            preferredLanguages: locale.rLanguages
        )
    }
}
