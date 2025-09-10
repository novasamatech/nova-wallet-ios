import Foundation

extension StackStatusCell {
    func bind(status: WalletConnectSessionViewModel.Status, locale: Locale) {
        switch status {
        case .active:
            statusView.apply(style: .active)
            statusView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonStatusActive()
        case .expired:
            statusView.apply(style: .inactive)
            statusView.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonStatusExpired()
        }
    }
}
