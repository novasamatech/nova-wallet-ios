import Foundation
import Operation_iOS
import NovaAppAttest

/// Builds the events POST. The body is the `Data` it is handed and nothing else: the
/// assertion signs those exact bytes, so a re-encode here would break every request.
public final class AnalyticsUploadOperationFactory {
    private let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Internal rather than private so the request contract is testable without a
    /// network stack.
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

// MARK: - Private

private extension AnalyticsUploadOperationFactory {
    enum Constants {
        static let eventsPath = "v1/analytics/events"
        static let timeout: TimeInterval = 15
    }

    static func statusError(for statusCode: Int) -> AnalyticsTransportError? {
        switch statusCode {
        case 401, 403:
            return .rejected(statusCode: statusCode)
        case 400 ..< 500:
            return .clientError(statusCode: statusCode)
        case 500...:
            return .serverError(statusCode: statusCode)
        default:
            return nil
        }
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

            if
                let httpResponse = response as? HTTPURLResponse,
                let statusError = Self.statusError(for: httpResponse.statusCode) {
                return .failure(statusError)
            }

            // A 2xx with an empty body is the expected success, so nothing is parsed.
            return .success(())
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
