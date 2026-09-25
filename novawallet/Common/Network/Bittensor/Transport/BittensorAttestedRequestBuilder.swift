import Foundation
import Operation_iOS
import NovaAppAttest

struct BittensorAttestedPreparedRequest {
    let context: BittensorAttestationContext
    let target: AttestationRequestTarget
    let body: Data?
    let isRecommendationsRoute: Bool
}

enum BittensorAttestedRequestBuilder {
    static let requestTimeout: TimeInterval = 45

    static func prepare(
        _ request: BittensorApiRequest,
        context: BittensorAttestationContext
    ) throws -> BittensorAttestedPreparedRequest {
        switch (request.method, request.jsonBody) {
        case (.get, nil), (.post, .some):
            break
        case (.get, .some), (.post, nil):
            throw BittensorApiError.invalidRequest(code: nil, requestId: nil)
        }

        let contentType = request.jsonBody == nil ? "" : Constants.jsonContentType

        let target: AttestationRequestTarget

        do {
            target = try AttestationRequestTarget(
                url: try createURL(for: request, baseURL: context.baseURL),
                method: request.method.rawValue,
                contentType: contentType
            )
        } catch {
            throw BittensorApiError.configuration
        }

        return BittensorAttestedPreparedRequest(
            context: context,
            target: target,
            body: request.jsonBody,
            isRecommendationsRoute: isRecommendationsRoute(request.pathTemplate)
        )
    }

    static func createSendOperation(
        for prepared: BittensorAttestedPreparedRequest,
        headers: [AttestationHeaderKey: String],
        session: URLSession
    ) -> NetworkOperation<BittensorAttestedResponse> {
        let target = prepared.target
        let body = prepared.body

        let requestFactory = BlockNetworkRequestFactory {
            var urlRequest = URLRequest(
                url: target.url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: requestTimeout
            )

            urlRequest.httpMethod = target.method

            if let body {
                urlRequest.httpBody = body
                urlRequest.setValue(target.contentType, forHTTPHeaderField: Constants.contentTypeHeader)
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
                    contentType: httpResponse.value(forHTTPHeaderField: Constants.contentTypeHeader),
                    requestId: httpResponse.value(forHTTPHeaderField: Constants.requestIdHeader),
                    body: data ?? Data()
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
        static let jsonContentType = "application/json"
        static let contentTypeHeader = "Content-Type"
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
