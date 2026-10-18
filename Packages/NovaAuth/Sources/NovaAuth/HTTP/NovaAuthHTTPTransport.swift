import Foundation
import Operation_iOS

final class NovaAuthHTTPTransport: NovaAuthHTTPProtocol {
    private let session: URLSession
    private let watchdogTimeout: TimeInterval

    init(protocolClasses: [AnyClass]? = nil, watchdogTimeout: TimeInterval = 110) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 100
        configuration.waitsForConnectivity = false
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        self.watchdogTimeout = watchdogTimeout
        session = URLSession(configuration: configuration, delegate: NovaAuthHTTPDelegate(), delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    func createResponseWrapper<T>(
        for request: URLRequest,
        kind: NovaAuthHTTPKind,
        beforeSend: @escaping () throws -> Void,
        decode: @escaping (NovaAuthResponse) throws -> T
    ) -> CompoundOperationWrapper<T> {
        do {
            try Self.validate(request, kind: kind)
        } catch { return .createWithError(error) }
        var frozen = request
        frozen.cachePolicy = .reloadIgnoringLocalCacheData
        frozen.httpShouldHandleCookies = false
        frozen.timeoutInterval = kind == .bootstrap && request.url?.path == NovaAuthPurpose.registration.path ? 100 : 20
        let limit = kind == .bootstrap ? 16384 : 32 * 1024 * 1024
        let watchdog = NovaAuthHTTPWatchdog<T>(timeout: watchdogTimeout)
        let operation = NetworkOperation(
            requestFactory: BlockNetworkRequestFactory {
                try beforeSend()
                watchdog.arm()
                return frozen
            },
            resultFactory: AnyNetworkResultFactory<T> { data, response, error in
                guard watchdog.settle() else { return .failure(NovaAuthError.transport(.timedOut)) }
                return Result {
                    try decode(Self.response(to: frozen, data: data, response: response, error: error, limit: limit))
                }
            }
        )
        watchdog.operation = operation
        operation.networkSession = session
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

private extension NovaAuthHTTPTransport {
    static func response(
        to request: URLRequest,
        data: Data?,
        response: URLResponse?,
        error: Error?,
        limit: Int
    ) throws -> NovaAuthResponse {
        if let error { throw NovaAuthError.transport((error as? URLError)?.code ?? .unknown) }
        guard let response = response as? HTTPURLResponse, response.url == request.url,
              !(300 ..< 400).contains(response.statusCode) else { throw NovaAuthError.invalidResponse }
        let body = data ?? Data()
        guard body.count <= limit else { throw NovaAuthError.invalidResponse }
        return NovaAuthResponse(response: response, body: body)
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
                path: components.path,
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
