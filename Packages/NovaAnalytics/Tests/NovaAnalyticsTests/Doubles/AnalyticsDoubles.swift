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
    var flushStub: (Int) -> CompoundOperationWrapper<Void> = { _ in .createWithResult(()) }

    private let recordedMaxBatches = Locked<[Int]>([])

    var maxBatchesCalls: [Int] { recordedMaxBatches.value }

    var flushCallCount: Int { maxBatchesCalls.count }

    func reset() {
        recordedMaxBatches.update { $0 = [] }
    }

    func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void> {
        recordedMaxBatches.update { $0.append(maxBatches) }

        return flushStub(maxBatches)
    }
}

final class AnalyticsUploadOperationFactorySpy: AnalyticsUploadOperationFactoryProtocol {
    var uploadResults: [Result<Void, Error>] = []

    private let recordedBodies = Locked<[Data]>([])
    private let recordedCalls = Locked(0)

    var sentBodies: [Data] { recordedBodies.value }

    var callCount: Int { recordedCalls.value }

    func createUploadOperation(
        bodyClosure: @escaping () throws -> Data,
        headersClosure _: @escaping () throws -> [AttestationHeaderKey: String]?
    ) -> BaseOperation<Void> {
        recordedCalls.update { $0 += 1 }

        let next: Result<Void, Error> = uploadResults.isEmpty ? .success(()) : uploadResults.removeFirst()
        let bodies = recordedBodies

        return ClosureOperation {
            let body = try bodyClosure()
            bodies.update { $0.append(body) }

            try next.get()
        }
    }
}

final class BackendAttestationProviderSpy: BackendAttestationProviderProtocol {
    private let recordedBodies = Locked<[Data]>([])
    private let recordedMarkUnattested = Locked(0)

    var signedBodies: [Data] { recordedBodies.value }

    var markUnattestedCallCount: Int { recordedMarkUnattested.value }

    func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let bodies = recordedBodies

        return CompoundOperationWrapper(
            targetOperation: ClosureOperation<[AttestationHeaderKey: String]?> {
                let body = try bodyClosure()
                bodies.update { $0.append(body) }

                return [.clientId: "cid", .challenge: "chal", .signature: "sig"]
            }
        )
    }

    func markUnattested() {
        recordedMarkUnattested.update { $0 += 1 }
    }

    func forgetClient() {}

    func allowClient() {}
}
