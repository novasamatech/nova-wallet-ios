import Foundation

protocol InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLink.Params) -> URL?
}

class BaseInternalLinkFactory {
    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }
}
