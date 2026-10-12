import Foundation
import Operation_iOS
import NovaOperationSupport

final class NovaAuthHTTPTransport: NovaAuthHTTPProtocol {
    private let delegate: NovaAuthHTTPDelegate
    private let bootstrap: URLSession
    private let reads: URLSession
    private let posts: URLSession
    private let cache: URLCache

    init(
        protocolClasses: [AnyClass]? = nil,
        cache: URLCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 0)
    ) {
        self.cache = cache
        delegate = NovaAuthHTTPDelegate()
        bootstrap = Self.session(kind: .bootstrap, delegate: delegate, cache: nil, protocolClasses: protocolClasses)
        reads = Self.session(kind: .businessRead, delegate: delegate, cache: cache, protocolClasses: protocolClasses)
        posts = Self.session(kind: .businessPost, delegate: delegate, cache: nil, protocolClasses: protocolClasses)
    }

    deinit {
        bootstrap.invalidateAndCancel()
        reads.invalidateAndCancel()
        posts.invalidateAndCancel()
    }

    func clearReadCache() { cache.removeAllCachedResponses() }

    func createResponseWrapper(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        do {
            try Self.validate(request, kind: kind)
            var frozenRequest = request
            frozenRequest.cachePolicy = kind == .businessRead ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData
            frozenRequest.httpShouldHandleCookies = false
            let timeout: TimeInterval = kind == .bootstrap && request.url?.path == NovaAuthPurpose.registration
                .path ? 100 : 20
            frozenRequest.timeoutInterval = timeout
            let session = kind == .bootstrap ? bootstrap : (kind == .businessRead ? reads : posts)
            let delegate = delegate
            let pending = NovaAuthHTTPCall(request: frozenRequest, kind: kind, timeout: timeout)
            let operation = AsyncClosureOperation<NovaAuthResponse>(operationClosure: { completion in
                let task = session.dataTask(with: frozenRequest)
                pending.prepare(task: task, completion: completion)
                delegate.insert(pending, for: task, session: session)
                do {
                    try beforeSend()
                    try pending.resume()
                } catch {
                    delegate.remove(task: task, session: session)
                    pending.finish(.failure(error))
                }
            }, cancelationClosure: { pending.finish(.failure(NovaAuthError.cancelled)) })
            return CompoundOperationWrapper(targetOperation: operation)
        } catch { return .createWithError(error) }
    }
}

private extension NovaAuthHTTPTransport {
    static func session(
        kind: NovaAuthHTTPKind,
        delegate: NovaAuthHTTPDelegate,
        cache: URLCache?,
        protocolClasses: [AnyClass]?
    ) -> URLSession {
        let configuration = kind == .businessRead ? URLSessionConfiguration.default : .ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = cache
        configuration
            .requestCachePolicy = kind == .businessRead ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = kind == .bootstrap ? 100 : 20
        configuration.waitsForConnectivity = false
        configuration.protocolClasses = protocolClasses
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    static func validate(_ request: URLRequest, kind: NovaAuthHTTPKind) throws {
        guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https", let host = components.host, components.user == nil,
              components.password == nil, components.fragment == nil, request.httpBodyStream == nil else {
            throw NovaAuthError.invalidRequest
        }
        let origin = "https://" + host + (components.port.map { ":\($0)" } ?? "")
        _ = try NovaAuthOrigin(origin)
        let headers = request.allHTTPHeaderFields ?? [:]
        let forbidden = [
            "cookie",
            "cookie2",
            "transfer-encoding",
            "te",
            "trailer",
            "content-encoding",
            "proxy-authorization"
        ]
        guard !headers.keys.contains(where: {
            let key = $0.lowercased()
            return forbidden.contains(key) || key.hasPrefix("x-client-") || key.hasPrefix("x-attestation") ||
                key.hasPrefix("x-app-attest") || key == "x-challenge" || key == "x-signature"
        }) else { throw NovaAuthError.invalidRequest }
        if kind == .bootstrap {
            try validateBootstrap(request, components: components)
        } else {
            guard let method = request.httpMethod.flatMap(NovaAuthMethod.init(rawValue:)),
                  (kind == .businessRead && method != .post) || (kind == .businessPost && method == .post),
                  let authorization = request.value(forHTTPHeaderField: "Authorization"),
                  authorization.hasPrefix("Bearer ") else { throw NovaAuthError.invalidRequest }
            try NovaAuthValidation.token(String(authorization.dropFirst(7)))
            try NovaAuthRoute.validate(
                method: method,
                path: components.percentEncodedPath,
                body: request.httpBody,
                contentType: request.value(forHTTPHeaderField: "Content-Type")
            )
        }
    }

    static func validateBootstrap(_ request: URLRequest, components: URLComponents) throws {
        let limits = ["/v1/attestation/profile-3/challenges": 1024,
                      "/v1/attestation/profile-3/token-challenges": 1024,
                      NovaAuthPurpose.registration.path: 98304, NovaAuthPurpose.token.path: 16384]
        guard request.httpMethod == "POST", let limit = limits[components.percentEncodedPath],
              components.percentEncodedQuery == nil, let body = request.httpBody, body.count <= limit,
              request.value(forHTTPHeaderField: "Authorization") == nil,
              request.value(forHTTPHeaderField: "Content-Length") == String(body.count),
              let contentType = request.value(forHTTPHeaderField: "Content-Type")
        else { throw NovaAuthError.invalidRequest }
        try NovaAuthValidation.contentType(contentType)
    }
}
