import Foundation
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
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable.self
        switch self {
        case let .accountNotFound(name):
            title = strings.transferSetupErrorW3nAccountNotFoundTitle()
            message = strings.transferSetupErrorW3nAccountNotFoundSubtitle(
                KiltW3n.fullName(for: name)
            )
        case let .serviceNotFound(name, chain):
            title = strings.transferSetupErrorW3nAccountNotFoundTitle()
            message = strings.transferSetupErrorW3nServiceNotFoundSubtitle(
                KiltW3n.fullName(for: name),
                chain
            )
        case let .invalidAddress(chain):
            title = strings.transferSetupErrorW3nAccountNotFoundTitle()
            message = strings.commonValidationInvalidAddressMessage(
                chain
            )
        case let .integrityNotPassed(name):
            title = strings.transferSetupErrorW3nIntegrityNotPassedTitle()
            let fullName = KiltW3n.fullName(for: name)
            message = strings.transferSetupErrorW3nIntegrityNotPassedSubtitle(
                fullName
            )
        case let .searchInProgress(name):
            title = strings.transferSetupErrorW3nSearchInProgressTitle()
            message = strings.transferSetupErrorW3nSearchInProgressSubtitle(
                name
            )
        case let .tokenNotFound(token):
            title = strings.transferSetupErrorW3nTokenNotFoundTitle(token)
            message = strings.transferSetupErrorW3nTokenNotFoundSubtitle(token)
        case let .internalFailure(providerName, _), let .slip44ListIsEmpty(providerName):
            title = strings.transferSetupErrorW3nKiltServiceUnavailableTitle()
            message = strings.transferSetupErrorW3nKiltServiceUnavailableSubtitle(
                providerName
            )
        }

        return ErrorContent(title: title, message: message)
    }
}
