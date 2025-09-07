import UIKit

extension UILabel {
    func bindQr(viewModel: ExpirationTimeViewModel, locale: Locale) {
        switch viewModel {
        case let .normal(time):
            textColor = R.color.colorTextSecondary()
            text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonQrCodeValidFormat(time)
        case let .expiring(time):
            textColor = R.color.colorTextNegative()
            text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonQrCodeValidFormat(time)
        case .expired:
            textColor = R.color.colorTextNegative()
            text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonQrCodeExpired()
        }
    }

    func bindTransaction(viewModel: ExpirationTimeViewModel, locale: Locale) {
        switch viewModel {
        case let .normal(time):
            textColor = R.color.colorTextSecondary()
            text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonTransactionValidFormat(time)
        case let .expiring(time):
            textColor = R.color.colorTextNegative()
            text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonTransactionValidFormat(time)
        case .expired:
            textColor = R.color.colorTextNegative()
            text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.commonTransactionExpired()
        }
    }
}
