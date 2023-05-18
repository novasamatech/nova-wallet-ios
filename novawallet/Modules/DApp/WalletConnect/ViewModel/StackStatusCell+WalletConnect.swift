import Foundation

extension StackStatusCell {
    func bind(status: WalletConnectSessionViewModel.Status, locale: Locale) {
        switch status {
        case .active:
            statusView.apply(style: .active)
            statusView.titleLabel.text = R.string.localizable.commonStatusActive(
                preferredLanguages: locale.rLanguages
            )
        case .expired:
            statusView.apply(style: .inactive)
            statusView.titleLabel.text = R.string.localizable.commonStatusExpired(
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
