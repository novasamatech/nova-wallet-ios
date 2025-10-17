import Foundation

enum CrowdloanBonusServiceError: Error, ErrorContentConvertible {
    case invalidReferral
    case internalError
    case veficationFailed

    func toErrorContent(for locale: Locale?) -> ErrorContent {
        switch self {
        case .invalidReferral:
            return ErrorContent(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonErrorGeneralTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.crowdloanReferralCodeInvalid()
            )
        case .internalError:
            return ErrorContent(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonErrorGeneralTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.crowdloanReferralCodeInternal()
            )
        case .veficationFailed:
            return ErrorContent(
                title: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.commonErrorGeneralTitle(),
                message: R.string(
                    preferredLanguages: locale.rLanguages
                ).localizable.crowdloanBonusVerificationError()
            )
        }
    }
}
