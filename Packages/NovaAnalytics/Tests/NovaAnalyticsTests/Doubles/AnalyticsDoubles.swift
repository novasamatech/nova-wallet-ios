import Foundation
import Operation_iOS
import NovaAppAttest
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

    private let recordedBodies = Locked<[Data]>([])

    var sentBodies: [Data] { recordedBodies.value }

    func eventsTarget() throws -> AttestationRequestTarget {
        try AttestationRequestTarget(
            url: URL(string: "https://gateway.example/v1/analytics/events")!,
            method: "post",
            contentType: "application/json"
        )
    }

    func createUploadOperation(
        target _: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data,
        headersClosure _: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void> {
        let result = uploadResult
        let bodies = recordedBodies

        return ClosureOperation {
            let body = try bodyClosure()
            bodies.update { $0.append(body) }

            try result.get()
        }
    }
}

final class BackendAttestationProviderSpy: BackendAttestationProviderProtocol {
    private let recordedBodies = Locked<[Data]>([])
    private let recordedMarkUnattested = Locked<[String]>([])

    var signedBodies: [Data] { recordedBodies.value }

    var markedUnattestedClientIds: [String] { recordedMarkUnattested.value }

    func createSignedHeadersWrapper(
        target _: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let bodies = recordedBodies

        return CompoundOperationWrapper(
            targetOperation: ClosureOperation<[AttestationHeaderKey: String]?> {
                let body = try bodyClosure()
                bodies.update { $0.append(body) }

                return [.profile: "2", .clientId: "cid", .challenge: "chal", .appAttestAssertion: "assertion"]
            }
        )
    }

    func markUnattested(ifCurrentClientId clientId: String) {
        recordedMarkUnattested.update { $0.append(clientId) }
    }

    func forgetClient() {}

    func allowClient() {}
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
    private let gateway: AnalyticsGateway

    private(set) var forgetCount: Int = 0
    private(set) var allowCount: Int = 0

    init(
        attestation: BackendAttestationProviderProtocol,
        uploadFactory: AnalyticsUploadOperationFactoryProtocol
    ) {
        gateway = AnalyticsGateway(attestation: attestation, uploadFactory: uploadFactory)
    }

    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway> {
        .createWithResult(gateway)
    }

    func forgetClient() {
        forgetCount += 1
    }

    func allowClient() {
        allowCount += 1
    }
}
