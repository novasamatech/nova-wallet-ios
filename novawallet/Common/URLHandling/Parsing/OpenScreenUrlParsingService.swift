import Foundation

protocol OpenScreenUrlParsingServiceProtocol: AnyObject {
    func parse(
        url: URL,
        completion: @escaping (Result<UrlHandlingScreen, DeeplinkParseError>) -> Void
    )
    func cancel()
}

enum DeeplinkParseError: Error {
    case openGovScreen(GovScreenError)
    case openDAppScreen(DAppError)

    enum GovScreenError: Error {
        case govTypeIsAmbiguous
        case emptyQueryParameters
        case invalidChainId
        case invalidReferendumId
        case chainNotSupportsGovType(type: String)
        case chainNotFound
    }

    enum DAppError: Error {
        case invalidURL
        case loadListFailed
        case unknownURL
    }
}
