import Foundation
import Operation_iOS
import NovaAppAttest

/// Builds the events POST from the exact `Data` it is handed, which the assertion signs.
public final class AnalyticsUploadOperationFactory {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    static func buildRequest(
        target: AttestationRequestTarget,
        body: Data,
        headers: [AttestationHeaderKey: String]?
    ) -> URLRequest {
        var request = URLRequest(url: target.url)

        request.httpMethod = target.method
        request.httpBody = body
        request.timeoutInterval = Constants.timeout
        request.setValue(target.contentType, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key.rawValue)
        }

        return request
    }
}

// MARK: - Delivery grading

extension AnalyticsUploadOperationFactory {
    enum Constants {
        static let eventsPath = "v1/analytics/events"
        static let timeout: TimeInterval = 15
        static let retryAfterHeader = "Retry-After"
        static let maxRetryAfter: TimeInterval = 86400
        static let ungradableStatusCode = 0
    }

    /// Only a graded 2xx lets the caller delete rows, so anything unreadable has to fail.
    ///
    /// This route crosses the gateway before it reaches telemetry, so a 4xx can be a verdict on the
    /// installation, a refused proof, or a rejected payload — and only the error code tells them
    /// apart. Grading an expired 60-second challenge as a verdict would burn an App Attest key on
    /// every late flush.
    static func deliveryError(
        for response: URLResponse?,
        data: Data?,
        now: Date
    ) -> AnalyticsTransportError? {
        guard let response = response as? HTTPURLResponse else {
            return .serverError(statusCode: Constants.ungradableStatusCode)
        }

        let code = AttestationHTTP.errorCode(from: data)

        switch response.statusCode {
        case 200 ..< 300:
            return nil
        case 401, 403, 409:
            guard let code else {
                // A proxy can answer with an empty or non-JSON 401; that is transport, not a verdict.
                return .proofRefused(statusCode: response.statusCode)
            }

            return code.requiresFreshInstallation
                ? .rejected(statusCode: response.statusCode)
                : .proofRefused(statusCode: response.statusCode)
        case 408, 425, 429, 503:
            return .retryLater(
                statusCode: response.statusCode,
                retryAfter: retryAfter(from: response, now: now)
            )
        case 400:
            // The gateway's own 400s describe the proof and are worth proving again; a 400 telemetry
            // raised about the payload never will be.
            return code == nil
                ? .clientError(statusCode: response.statusCode)
                : .proofRefused(statusCode: response.statusCode)
        case 413, 415, 422:
            return .clientError(statusCode: response.statusCode)
        default:
            return .serverError(statusCode: response.statusCode)
        }
    }

    static func retryAfter(from response: HTTPURLResponse, now: Date) -> TimeInterval? {
        let raw = response
            .value(forHTTPHeaderField: Constants.retryAfterHeader)?
            .trimmingCharacters(in: .whitespaces)

        guard let raw, !raw.isEmpty else {
            return nil
        }

        if let seconds = Int(raw) {
            return sanitised(TimeInterval(seconds))
        }

        guard let date = HTTPDateFormatter.date(from: raw) else {
            return nil
        }

        return sanitised(date.timeIntervalSince(now))
    }

    /// A delay that has already elapsed tells the schedule no more than a missing header does.
    static func sanitised(_ retryAfter: TimeInterval) -> TimeInterval? {
        guard retryAfter > 0 else {
            return nil
        }

        return min(retryAfter, Constants.maxRetryAfter)
    }
}

// MARK: - AnalyticsUploadOperationFactoryProtocol

extension AnalyticsUploadOperationFactory: AnalyticsUploadOperationFactoryProtocol {
    public func eventsTarget() throws -> AttestationRequestTarget {
        try AttestationRequestTarget(
            url: baseURL.appending(path: Constants.eventsPath),
            method: HttpMethod.post.rawValue,
            contentType: HttpContentType.json.rawValue
        )
    }

    public func createUploadOperation(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data,
        headersClosure: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void> {
        let requestFactory = BlockNetworkRequestFactory {
            let body = try bodyClosure()
            let headers = try headersClosure()

            return Self.buildRequest(target: target, body: body, headers: headers)
        }

        let resultFactory = AnyNetworkResultFactory<Void> { data, response, error in
            if let error {
                return .failure(error)
            }

            if let deliveryError = Self.deliveryError(for: response, data: data, now: Date()) {
                return .failure(deliveryError)
            }

            return .success(())
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
        operation.networkSession = AttestationHTTP.session

        return operation
    }
}
