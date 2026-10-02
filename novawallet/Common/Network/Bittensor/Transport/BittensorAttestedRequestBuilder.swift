import Foundation
import Operation_iOS
import NovaAppAttest

struct BittensorAttestedPreparedRequest {
    let provider: BackendAttestationProviderProtocol
    let target: AttestationRequestTarget
    let body: Data?
    let isRecommendationsRoute: Bool
    let route: String
}

enum BittensorAttestedRequestBuilder {
    static let requestTimeout: TimeInterval = 45

    static func prepare(
        _ request: BittensorApiRequest,
        endpoint: BackendAttestationEndpoint
    ) throws -> BittensorAttestedPreparedRequest {
        switch (request.method, request.jsonBody) {
        case (.get, nil), (.post, .some):
            break
        case (.get, .some), (.post, nil):
            throw BittensorApiError.invalidRequest(code: nil, requestId: nil)
        }

        let contentType = request.jsonBody == nil ? "" : HttpContentType.json.rawValue

        let target: AttestationRequestTarget

        do {
            target = try AttestationRequestTarget(
                url: try createURL(for: request, baseURL: endpoint.gatewayURL),
                method: request.method.rawValue,
                contentType: contentType
            )
        } catch {
            throw BittensorApiError.configuration
        }

        return BittensorAttestedPreparedRequest(
            provider: endpoint.provider,
            target: target,
            body: request.jsonBody,
            isRecommendationsRoute: isRecommendationsRoute(request.pathTemplate),
            route: "Bittensor \(request.method.rawValue) \(request.pathTemplate)"
        )
    }

    static func createSendOperation(
        for prepared: BittensorAttestedPreparedRequest,
        session: URLSession,
        headersClosure: @escaping () throws -> [AttestationHeaderKey: String]
    ) -> NetworkOperation<BittensorAttestedResponse> {
        let target = prepared.target
        let body = prepared.body

        let requestFactory = BlockNetworkRequestFactory {
            let headers = try headersClosure()

            var urlRequest = URLRequest(
                url: target.url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: requestTimeout
            )

            urlRequest.httpMethod = target.method

            if let body {
                urlRequest.httpBody = body
                urlRequest.setValue(target.contentType, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            }

            headers.forEach { key, value in
                urlRequest.setValue(value, forHTTPHeaderField: key.rawValue)
            }

            return urlRequest
        }

        let resultFactory = AnyNetworkResultFactory<BittensorAttestedResponse> { data, response, error in
            if let error {
                return .failure(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(URLError(.badServerResponse))
            }

            return .success(
                BittensorAttestedResponse(
                    statusCode: httpResponse.statusCode,
                    contentType: httpResponse.value(forHTTPHeaderField: HttpHeaderKey.contentType.rawValue),
                    requestId: httpResponse.value(forHTTPHeaderField: Constants.requestIdHeader),
                    body: data ?? Data(),
                    cacheDirectives: HTTPCacheDirectives(response: httpResponse)
                )
            )
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.networkSession = session

        return operation
    }
}

private extension BittensorAttestedRequestBuilder {
    enum Constants {
        static let apiRootPath = "/v1/bittensor"
        static let recommendationsPath = "/recommendations"
        static let requestIdHeader = "X-Request-ID"
    }

    static func normalizedRoute(_ path: String) -> String {
        path.hasPrefix("/") ? path : "/" + path
    }

    static func isRecommendationsRoute(_ pathTemplate: String) -> Bool {
        let route = normalizedRoute(pathTemplate)

        return route == Constants.recommendationsPath || route.hasPrefix(Constants.recommendationsPath + "/")
    }

    static func createURL(for request: BittensorApiRequest, baseURL: URL) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw BittensorApiError.configuration
        }

        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        let routePath = normalizedRoute(request.path)

        components.path = basePath + Constants.apiRootPath + routePath
        components.queryItems = request.queryItems.isEmpty ? nil : request.queryItems
        components.fragment = nil

        guard let url = components.url else {
            throw BittensorApiError.configuration
        }

        return url
    }
}
