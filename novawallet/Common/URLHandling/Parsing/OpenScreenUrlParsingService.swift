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

    func message(locale: Locale) -> String? {
        switch self {
        case let .openGovScreen(govScreenError):
            return govScreenError.message(locale: locale)
        case let .openDAppScreen(dAppError):
            return dAppError.message(locale: locale)
        case let .cardScreen(cardError):
            return nil
        }
    }
}

extension OpenScreenUrlParsingError.GovScreenError {
    func message(locale: Locale) -> String {
        let languages = locale.rLanguages
        switch self {
        case .govTypeIsNotSpecified:
            return R.string.localizable.deeplinkErrorNoGovernanceTypeMessage(
                preferredLanguages: languages)
        case .invalidChainId:
            return R.string.localizable.deeplinkErrorInvalidChainIdMessage(
                preferredLanguages: languages)
        case .invalidReferendumId:
            return R.string.localizable.deeplinkErrorInvalidReferendumIdMessage(
                preferredLanguages: languages)
        case .chainNotSupportsGovType, .chainNotSupportsGov:
            return R.string.localizable.deeplinkErrorInvalidGovernanceTypeMessage(
                preferredLanguages: languages)
        case .chainNotFound:
            return R.string.localizable.deeplinkErrorInvalidChainIdMessage(
                preferredLanguages: languages)
        }
    }
}

extension OpenScreenUrlParsingError.DAppError {
    func message(locale: Locale) -> String? {
        let languages = locale.rLanguages
        switch self {
        case .invalidURL:
            return R.string.localizable.deeplinkErrorInvalidDappUrlMessage(
                preferredLanguages: languages)
        case .loadListFailed, .unknownURL:
            return nil
        }
    }
}
