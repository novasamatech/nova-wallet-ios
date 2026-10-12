import Foundation
import Operation_iOS
import NovaAuth
import SDKLogger
import NovaOperationSupport

public final class AnalyticsUploadOperationFactory {
    private let auth: AnalyticsAuth
    private let logger: SDKLoggerProtocol?

    public init(auth: AnalyticsAuth, logger: SDKLoggerProtocol? = nil) {
        self.auth = auth
        self.logger = logger
    }
}

// MARK: - Delivery grading

extension AnalyticsUploadOperationFactory {
    enum Constants {
        static let eventsPath = "/v1/analytics/events"
        static let timeout: TimeInterval = 15
        static let retryAfterHeader = "Retry-After"
        static let maxRetryAfter: TimeInterval = 86400
        static let ungradableStatusCode = 0
    }

    // Error codes distinguish identity, proof and payload failures, which require different retries.
    static func deliveryError(
        for response: URLResponse?,
        data: Data?,
        now: Date
    ) -> AnalyticsTransportError? {
        guard let response = response as? HTTPURLResponse else {
            return .serverError(statusCode: Constants.ungradableStatusCode)
        }

        let code = errorCode(from: data)

        switch response.statusCode {
        case 200 ..< 300:
            return nil
        case 401, 403, 409:
            return .proofRefused(statusCode: response.statusCode)
        case 408, 425, 429, 503:
            return .retryLater(
                statusCode: response.statusCode,
                retryAfter: retryAfter(from: response, now: now)
            )
        case 400:
            // Retry recognized attestation errors; other 400 responses reject the payload.
            let authCodes: Set<String> = [
                "invalid_request", "unsupported_profile", "invalid_target", "unsupported_platform",
                "unsupported_attestation_type", "unknown_client", "invalid_challenge", "invalid_proof",
                "invalid_token", "insufficient_scope"
            ]
            return code.map(authCodes.contains) == true
                ? .proofRefused(statusCode: response.statusCode)
                : .clientError(statusCode: response.statusCode)
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

    // An elapsed delay must not constrain the next attempt.
    static func sanitised(_ retryAfter: TimeInterval) -> TimeInterval? {
        guard retryAfter > 0 else {
            return nil
        }

        return min(retryAfter, Constants.maxRetryAfter)
    }
}

// MARK: - AnalyticsUploadOperationFactoryProtocol

extension AnalyticsUploadOperationFactory: AnalyticsUploadOperationFactoryProtocol {
    public func createUploadWrapper(
        body: Data,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Void> {
        do {
            let request = try NovaAuthRequest(
                context: auth.context,
                method: .post,
                path: Constants.eventsPath,
                queryItems: [],
                body: body,
                contentType: "application/json",
                intent: .background
            )
            let responseWrapper = auth.client.createResponseWrapper(for: request, beforeSend: beforeSend)
            let grade = ClosureOperation<Void> { [logger] in
                let result = try responseWrapper.targetOperation.extractNoCancellableResultData()
                if let error = Self.deliveryError(for: result.response, data: result.body, now: Date()) {
                    logger?.warning("Analytics delivery refused: HTTP \(result.response.statusCode)")
                    throw error
                }
            }
            grade.addDependency(responseWrapper.targetOperation)
            return responseWrapper.insertingTail(operation: grade)
        } catch {
            return .createWithError(error)
        }
    }
}

private extension AnalyticsUploadOperationFactory {
    static func errorCode(from data: Data?) -> String? {
        guard let data, data.count <= 8192,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any],
              let code = error["code"] as? String, code.utf8.count <= 64,
              code.utf8.allSatisfy({ (97 ... 122).contains($0) || $0 == 95 }) else { return nil }
        return code
    }
}
