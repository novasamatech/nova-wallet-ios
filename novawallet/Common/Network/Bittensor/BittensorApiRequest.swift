import Foundation

struct BittensorApiRequest: Equatable {
    let path: String
    let pathTemplate: String
    let queryItems: [URLQueryItem]
}

struct BittensorApiRawResponse: Equatable {
    let statusCode: Int
    let requestId: String?
    let body: Data
    let cacheDirectives: HTTPCacheDirectives
}
