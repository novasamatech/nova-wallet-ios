import Foundation

struct BittensorApiRequest: Equatable {
    enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    let method: Method
    let path: String
    let pathTemplate: String
    let queryItems: [URLQueryItem]
    let jsonBody: Data?
}

struct BittensorApiRawResponse: Equatable {
    let statusCode: Int
    let requestId: String?
    let body: Data
    let cacheDirectives: HTTPCacheDirectives
}
