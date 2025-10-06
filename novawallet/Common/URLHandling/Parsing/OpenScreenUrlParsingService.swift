import Foundation

protocol OpenScreenUrlParsingServiceProtocol: AnyObject {
    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, OpenScreenUrlParsingError>) -> Void
    )
    func cancel()
}

enum OpenScreenUrlParsingError: Error {
    case openGovScreen(GovScreenError)
    case openDAppScreen(DAppError)
    case openAHMScreen(AHMError)
    case cardScreen(CardError)

    enum GovScreenError: Error {
        case govTypeIsNotSpecified
        case invalidChainId
        case invalidReferendumId
        case chainNotSupportsGovType(type: String)
        case chainNotSupportsGov
        case chainNotFound
    }

    enum DAppError: Error {
        case invalidURL
        case loadListFailed
        case unknownURL
    }

    enum CardError: Error {
        case unsupportedProvider
    }

    enum AHMError: Error {
        case migrationDataNotFound
    }

    func message(locale: Locale) -> String? {
        switch self {
        case let .openGovScreen(govScreenError):
            govScreenError.message(locale: locale)
        case let .openDAppScreen(dAppError):
            dAppError.message(locale: locale)
        case let .openAHMScreen(ahmError):
            ahmError.message(locale: locale)
        case .cardScreen:
            nil
        }
    }
}

extension OpenScreenUrlParsingError.GovScreenError {
    func message(locale: Locale) -> String {
        let languages = locale.rLanguages

        return switch self {
        case .govTypeIsNotSpecified:
            R.string.localizable.deeplinkErrorNoGovernanceTypeMessage(
                preferredLanguages: languages)
        case .invalidChainId:
            R.string.localizable.deeplinkErrorInvalidChainIdMessage(
                preferredLanguages: languages)
        case .invalidReferendumId:
            R.string.localizable.deeplinkErrorInvalidReferendumIdMessage(
                preferredLanguages: languages)
        case .chainNotSupportsGovType, .chainNotSupportsGov:
            R.string.localizable.deeplinkErrorInvalidGovernanceTypeMessage(
                preferredLanguages: languages)
        case .chainNotFound:
            R.string.localizable.deeplinkErrorInvalidChainIdMessage(
                preferredLanguages: languages)
        }
    }
}

extension OpenScreenUrlParsingError.DAppError {
    func message(locale: Locale) -> String? {
        let languages = locale.rLanguages

        return switch self {
        case .invalidURL:
            R.string.localizable.deeplinkErrorInvalidDappUrlMessage(
                preferredLanguages: languages)
        case .loadListFailed, .unknownURL:
            nil
        }
    }
}

extension OpenScreenUrlParsingError.AHMError {
    func message(locale: Locale) -> String? {
        let languages = locale.rLanguages

        return switch self {
        case .migrationDataNotFound:
            R.string.localizable.ahmInfoNotFoundError(preferredLanguages: languages)
        }
    }
}
