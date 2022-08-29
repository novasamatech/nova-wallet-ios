import UIKit

extension UILabel {
    func bindQr(viewModel: ExpirationTimeViewModel, locale: Locale) {
        switch viewModel {
        case let .normal(time):
            textColor = R.color.colorWhite()
            text = R.string.localizable.commonQrCodeValidFormat(
                time,
                preferredLanguages: locale.rLanguages
            )
        case let .expiring(time):
            textColor = R.color.colorRed()
            text = R.string.localizable.commonQrCodeValidFormat(
                time,
                preferredLanguages: locale.rLanguages
            )
        case .expired:
            textColor = R.color.colorRed()
            text = R.string.localizable.commonQrCodeExpired(
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func bindTransaction(viewModel: ExpirationTimeViewModel, locale: Locale) {
        switch viewModel {
        case let .normal(time):
            textColor = R.color.colorTransparentText()
            text = R.string.localizable.commonTransactionValidFormat(
                time,
                preferredLanguages: locale.rLanguages
            )
        case let .expiring(time):
            textColor = R.color.colorRed()
            text = R.string.localizable.commonTransactionValidFormat(
                time,
                preferredLanguages: locale.rLanguages
            )
        case .expired:
            textColor = R.color.colorRed()
            text = R.string.localizable.commonTransactionExpired(
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
