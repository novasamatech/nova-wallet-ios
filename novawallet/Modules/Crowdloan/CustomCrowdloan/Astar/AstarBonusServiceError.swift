import Foundation

enum AstarBonusServiceError: Error, ErrorContentConvertible {
    case invalidReferral

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .invalidReferral:
            return ErrorContent(
                title: R.string.localizable.commonErrorGeneralTitle(preferredLanguages: locale?.rLanguages),
                message: R.string.localizable.crowdloanAstarInvalidReferralMessage(
                    preferredLanguages: locale?.rLanguages
                )
            )
        }
    }
}
