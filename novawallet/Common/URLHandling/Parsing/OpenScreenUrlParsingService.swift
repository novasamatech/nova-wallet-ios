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
            R.string(preferredLanguages: languages).localizable.deeplinkErrorNoGovernanceTypeMessage()
        case .invalidChainId:
            R.string(preferredLanguages: languages).localizable.deeplinkErrorInvalidChainIdMessage()
        case .invalidReferendumId:
            R.string(preferredLanguages: languages).localizable.deeplinkErrorInvalidReferendumIdMessage()
        case .chainNotSupportsGovType, .chainNotSupportsGov:
            R.string(preferredLanguages: languages).localizable.deeplinkErrorInvalidGovernanceTypeMessage()
        case .chainNotFound:
            R.string(preferredLanguages: languages).localizable.deeplinkErrorInvalidChainIdMessage()
        }
    }
}

extension OpenScreenUrlParsingError.DAppError {
    func message(locale: Locale) -> String? {
        let languages = locale.rLanguages

        return switch self {
        case .invalidURL:
            R.string(preferredLanguages: languages).localizable.deeplinkErrorInvalidDappUrlMessage()
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
            R.string(
                preferredLanguages: languages
            ).localizable.ahmInfoNotFoundError()
        }
    }
}
