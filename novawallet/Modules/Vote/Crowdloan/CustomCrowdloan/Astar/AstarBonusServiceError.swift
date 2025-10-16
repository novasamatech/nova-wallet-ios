import Foundation

enum AstarBonusServiceError: Error, ErrorContentConvertible {
    case invalidReferral

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .invalidReferral:
            return ErrorContent(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonErrorGeneralTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.crowdloanAstarInvalidReferralMessage()
            )
        }
    }
}
