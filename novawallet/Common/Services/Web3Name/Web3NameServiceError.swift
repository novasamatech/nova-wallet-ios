import Foundation_iOS

enum Web3NameServiceError: Error {
    typealias Chain = String
    typealias Name = String

    case accountNotFound(Name)
    case serviceNotFound(Name, Chain)
    case slip44ListIsEmpty(String)
    case internalFailure(String, Error)
    case invalidAddress(Chain)
    case integrityNotPassed(Name)
    case searchInProgress(Name)
    case tokenNotFound(token: String)
}

extension Web3NameServiceError: ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent {
        let title: String
        let message: String
        let strings = R.string.localizable.self
        switch self {
        case let .accountNotFound(name):
            title = strings.transferSetupErrorW3nAccountNotFoundTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nAccountNotFoundSubtitle(
                KiltW3n.fullName(for: name),
                preferredLanguages: locale?.rLanguages
            )
        case let .serviceNotFound(name, chain):
            title = strings.transferSetupErrorW3nAccountNotFoundTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nServiceNotFoundSubtitle(
                KiltW3n.fullName(for: name),
                chain,
                preferredLanguages: locale?.rLanguages
            )
        case let .invalidAddress(chain):
            title = strings.transferSetupErrorW3nAccountNotFoundTitle(preferredLanguages: locale?.rLanguages)
            message = strings.commonValidationInvalidAddressMessage(
                chain,
                preferredLanguages: locale?.rLanguages
            )
        case let .integrityNotPassed(name):
            title = strings.transferSetupErrorW3nIntegrityNotPassedTitle(preferredLanguages: locale?.rLanguages)
            let fullName = KiltW3n.fullName(for: name)
            message = strings.transferSetupErrorW3nIntegrityNotPassedSubtitle(
                fullName,
                preferredLanguages: locale?.rLanguages
            )
        case let .searchInProgress(name):
            title = strings.transferSetupErrorW3nSearchInProgressTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nSearchInProgressSubtitle(
                name,
                preferredLanguages: locale?.rLanguages
            )
        case let .tokenNotFound(token):
            title = strings.transferSetupErrorW3nTokenNotFoundTitle(token, preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nTokenNotFoundSubtitle(token, preferredLanguages: locale?.rLanguages)
        case let .internalFailure(providerName, _), let .slip44ListIsEmpty(providerName):
            title = strings.transferSetupErrorW3nKiltServiceUnavailableTitle(preferredLanguages: locale?.rLanguages)
            message = strings.transferSetupErrorW3nKiltServiceUnavailableSubtitle(
                providerName,
                preferredLanguages: locale?.rLanguages
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
