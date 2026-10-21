import Foundation

struct BittensorApiRequest: Equatable {
    let path: String
    let queryItems: [URLQueryItem]
}

struct BittensorApiRawResponse: Equatable {
    let requestId: String?
    let body: Data
    let directives: HTTPCacheDirectives
}
