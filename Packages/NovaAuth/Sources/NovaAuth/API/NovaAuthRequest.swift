import Foundation
import Operation_iOS

public enum NovaAuthRequestIntent: Equatable { case userInitiated, background }
public enum NovaAuthMethod: String { case get = "GET", head = "HEAD", post = "POST" }

public struct NovaAuthRequest {
    public let context: NovaAuthContext
    public let method: NovaAuthMethod
    public let path: String
    public let queryItems: [URLQueryItem]
    public let body: Data?
    public let contentType: String?
    public let intent: NovaAuthRequestIntent

    public init(
        context: NovaAuthContext,
        method: NovaAuthMethod,
        path: String,
        queryItems: [URLQueryItem],
        body: Data?,
        contentType: String?,
        intent: NovaAuthRequestIntent
    ) throws {
        try NovaAuthRoute.validate(method: method, path: path, body: body, contentType: contentType)
        self.context = context
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.contentType = contentType
        self.intent = intent
        _ = try makeURL()
    }

    func makeURL() throws -> URL {
        guard var components = URLComponents(string: context.origin.value) else { throw NovaAuthError.invalidRequest }
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url, components.fragment == nil,
              url.absoluteString.utf8.count <= 2048,
              url.scheme == "https", url.host == context.origin.url.host,
              url.port == context.origin.url.port, url.path == path else { throw NovaAuthError.invalidRequest }
        return url
    }
}

public struct NovaAuthResponse {
    public let response: HTTPURLResponse
    public let body: Data

    public init(response: HTTPURLResponse, body: Data) {
        self.response = response
        self.body = body
    }
}

public protocol NovaAuthClientProtocol: AnyObject {
    var isSupported: Bool { get }
    func createAdmissionWrapper(
        in context: NovaAuthContext,
        intent: NovaAuthRequestIntent
    ) -> CompoundOperationWrapper<Void>
    func createResponseWrapper(
        for request: NovaAuthRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse>
}
