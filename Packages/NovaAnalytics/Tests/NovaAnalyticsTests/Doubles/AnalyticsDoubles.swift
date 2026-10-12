import Foundation
import Operation_iOS
import NovaAuth
@testable import NovaAnalytics

final class AnalyticsTrackingSpy: AnalyticsTrackingProtocol {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var flushReasons: [AnalyticsFlushReason] = []

    var eventNames: [String] { events.map(\.name.rawValue) }

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func trackAndFlush(
        _ event: AnalyticsEvent,
        reason: AnalyticsFlushReason,
        completion: @escaping () -> Void
    ) {
        events.append(event)
        flushReasons.append(reason)
        completion()
    }
}

final class AnalyticsUploadingSpy: AnalyticsUploading {
    private let recordedMaxBatches = Locked<[Int]>([])

    var maxBatchesCalls: [Int] { recordedMaxBatches.value }

    func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void> {
        recordedMaxBatches.update { $0.append(maxBatches) }

        return .createWithResult(())
    }
}

final class AnalyticsUploadOperationFactorySpy: AnalyticsUploadOperationFactoryProtocol {
    var uploadResult: Result<Void, Error> = .success(())
    var onBeforeSend: (() -> Void)?
    private let recordedBodies = Locked<[Data]>([])
    var sentBodies: [Data] { recordedBodies.value }

    func createUploadWrapper(body: Data, beforeSend: @escaping () throws -> Void) -> CompoundOperationWrapper<Void> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in
            onBeforeSend?()
            try beforeSend()
            recordedBodies.update { $0.append(body) }
            try uploadResult.get()
        })
    }
}

final class AnalyticsAuthClientSpy: NovaAuthClientProtocol {
    let isSupported = true
    var responseStatus = 204
    var responseBody = Data()
    var failure: Error?
    var onBeforeSend: (() -> Void)?
    var simulateRecovery = false
    private let recordedRequests = Locked<[NovaAuthRequest]>([])
    var requests: [NovaAuthRequest] { recordedRequests.value }
    let identitySentinel = UUID()

    func createAdmissionWrapper(in _: NovaAuthContext, intent _: NovaAuthRequestIntent) -> CompoundOperationWrapper<Void> {
        .createWithResult(())
    }

    func createResponseWrapper(
        for request: NovaAuthRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthResponse> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [self] in
            if let failure { throw failure }
            onBeforeSend?()
            try beforeSend()
            recordedRequests.update { $0.append(request) }
            if simulateRecovery {
                onBeforeSend?()
                try beforeSend()
                recordedRequests.update { $0.append(request) }
            }
            let url = request.context.origin.url.appendingPathComponent(request.path)
            let response = HTTPURLResponse(url: url, statusCode: responseStatus, httpVersion: nil, headerFields: nil)!
            return NovaAuthResponse(response: response, body: responseBody)
        })
    }
}

func analyticsTestAuth(_ client: NovaAuthClientProtocol) -> AnalyticsAuth {
    let context = try! JSONDecoder().decode(
        NovaAuthContext.self,
        from: Data(#"{"origin":"https://gateway.example","generation":1}"#.utf8)
    )
    return AnalyticsAuth(context: context, client: client)
}

final class AnalyticsAvailabilityStub: AnalyticsAvailabilityProviderProtocol {
    let isAvailable = true

    func addObserver(with _: AnyObject, queue _: DispatchQueue?, closure _: @escaping (Bool) -> Void) {}
    func removeObserver(by _: AnyObject) {}
}

final class AnalyticsConsentStub: AnalyticsConsentManagerProtocol {
    var isEnabled: Bool
    let isAvailable = true
    let isPromptSeen = true
    var isErasureOwed = false

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func setEnabled(_ enabled: Bool) { isEnabled = enabled }
    func setErasureOwed(_ owed: Bool) { isErasureOwed = owed }
    func markPromptSeen() {}
    func addObserver(with _: AnyObject, queue _: DispatchQueue?, closure _: @escaping (Bool, Bool) -> Void) {}
    func removeObserver(by _: AnyObject) {}
    func addAvailabilityObserver(with _: AnyObject, queue _: DispatchQueue?, closure _: @escaping (Bool) -> Void) {}
    func removeAvailabilityObserver(by _: AnyObject) {}
}

final class AnalyticsIdentityStub: AnalyticsIdentityProtocol {
    let sessionId = "66666666-7777-8888-9999-000000000000"
    let consentEpoch = 0

    func installId() -> String? { "11111111-2222-3333-4444-555555555555" }
    func existingInstallId() -> String? { nil }
    func forgetInstallId() {}
    func allowCreation() {}
}

final class AnalyticsGatewayResolverStub: AnalyticsGatewayResolving {
    private let factory: AnalyticsUploadOperationFactoryProtocol
    init(uploadFactory: AnalyticsUploadOperationFactoryProtocol) { factory = uploadFactory }
    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway> {
        .createWithResult(AnalyticsGateway(uploadFactory: factory))
    }
}

final class AnalyticsAuthSourceStub: AnalyticsAuthProvidingProtocol {
    let auth: AnalyticsAuth
    init(auth: AnalyticsAuth) { self.auth = auth }
    func createAuthWrapper() -> CompoundOperationWrapper<AnalyticsAuth> { .createWithResult(auth) }
}
