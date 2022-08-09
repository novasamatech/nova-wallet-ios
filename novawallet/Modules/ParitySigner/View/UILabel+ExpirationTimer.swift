import UIKit

extension UILabel {
    func bind(viewModel: ExpirationTimeViewModel, locale: Locale) {
        switch viewModel {
        case let .normal(time):
            textColor = R.color.colorWhite()
            text = R.string.localizable.commonTxQrNotExpiredTitle(
                time,
                preferredLanguages: locale.rLanguages
            )
        case let .expiring(time):
            textColor = R.color.colorRed()
            text = R.string.localizable.commonTxQrNotExpiredTitle(
                time,
                preferredLanguages: locale.rLanguages
            )
        case .expired:
            textColor = R.color.colorRed()
            text = R.string.localizable.commonTxQrExpiredTitle(
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
