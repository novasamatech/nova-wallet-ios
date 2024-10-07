import Foundation

struct PayCardHtmlResource {
    let url: URL
    let content: String
}

protocol PayCardResourceProviding {
    func loadResource() throws -> PayCardHtmlResource
}
