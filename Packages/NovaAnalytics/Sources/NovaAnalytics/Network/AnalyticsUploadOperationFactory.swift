import Foundation
import Operation_iOS
import NovaAppAttest

/// Builds the events POST from the exact `Data` it is handed, which the assertion signs.
public final class AnalyticsUploadOperationFactory {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func buildRequest(body: Data, headers: [AttestationHeaderKey: String]?) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: Constants.eventsPath))

        request.httpMethod = HttpMethod.post.rawValue
        request.httpBody = body
        request.timeoutInterval = Constants.timeout
        request.setValue(
            HttpContentType.json.rawValue,
            forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
        )

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
    static func deliveryError(for response: URLResponse?, now: Date) -> AnalyticsTransportError? {
        guard let response = response as? HTTPURLResponse else {
            return .serverError(statusCode: Constants.ungradableStatusCode)
        }

        switch response.statusCode {
        case 200 ..< 300:
            return nil
        case 401, 403:
            return .rejected(statusCode: response.statusCode)
        case 408, 425, 429, 503:
            return .retryLater(
                statusCode: response.statusCode,
                retryAfter: retryAfter(from: response, now: now)
            )
        case 400, 413, 422:
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
    public func createUploadOperation(
        bodyClosure: @escaping () throws -> Data,
        headersClosure: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void> {
        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            let body = try bodyClosure()
            let headers = try headersClosure()

            guard let self else {
                throw AnalyticsUploadAbort.consentWithdrawn
            }

            return try buildRequest(body: body, headers: headers)
        }

        let resultFactory = AnyNetworkResultFactory<Void> { _, response, error in
            if let error {
                return .failure(error)
            }

            if let deliveryError = Self.deliveryError(for: response, now: Date()) {
                return .failure(deliveryError)
            }

            return .success(())
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
