import Foundation

protocol OpenScreenUrlParsingServiceProtocol {
    func parse(url: URL) -> Result<UrlHandlingScreen, DeeplinkParseError>
}

enum DeeplinkParseError: Error {
    case openGovScreen(GovScreenError)

    enum GovScreenError: Error {
        case govTypeIsAmbiguous
        case emptyQueryParameters
        case invalidChainId
        case invalidReferendumId
        case chainNotSupportsGovType(type: String)
        case chainNotFound
    }
}
