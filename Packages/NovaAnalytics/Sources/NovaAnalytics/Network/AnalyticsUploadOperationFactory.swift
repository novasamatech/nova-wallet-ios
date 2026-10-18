import Foundation
import NovaAuth
import NovaOperationSupport
import Operation_iOS
import SDKLogger

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
    }

    static func deliveryError(for result: NovaAuthResponse) -> AnalyticsTransportError? {
        let status = result.response.statusCode
        switch status {
        case 200 ..< 300:
            return nil
        case 401, 403, 409:
            return .proofRefused(statusCode: status)
        case 408, 425, 429, 503:
            return .retryLater(statusCode: status, retryAfter: result.serverError.retryAfter)
        case 400, 413, 415, 422:
            return .clientError(statusCode: status)
        default:
            return .serverError(statusCode: status)
        }
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
                if let error = Self.deliveryError(for: result) {
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
