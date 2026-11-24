import Foundation

enum GiftTransferConfirmError: Error {
    case giftSubmissionFailed(giftAccountId: AccountId, underlyingError: Error?)
}

extension GiftTransferConfirmError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        return ErrorContent(title: strings.commonErrorGeneralTitle(), message: strings.commonTransactionFailed())
    }
}
