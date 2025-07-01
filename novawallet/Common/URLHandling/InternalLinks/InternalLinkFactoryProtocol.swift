import Foundation

protocol InternalLinkFactoryProtocol {
    func createInternalLink(from externalParams: ExternalUniversalLinkParams) -> URL?
}

class BaseInternalLinkFactory {
    let baseUrl: URL

    init(baseUrl: URL) {
        self.baseUrl = baseUrl
    }
}
