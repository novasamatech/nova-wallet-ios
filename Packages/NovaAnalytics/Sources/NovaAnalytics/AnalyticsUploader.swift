import Foundation
import Operation_iOS
import SDKLogger
import NovaAppAttest
import NovaOperationSupport

public enum AnalyticsUploadAbort: Error {
    case consentWithdrawn
}

/// peek → sign → POST → drop, repeated while the gateway keeps accepting batches.
public final class AnalyticsUploader {
    private let queue: AnalyticsEventQueueProtocol
    private let identity: AnalyticsIdentityProtocol
    private let attestation: BackendAttestationProviderProtocol
    private let uploadFactory: AnalyticsUploadOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let appVersion: String
    private let timeProvider: () -> Date
    private let logger: SDKLoggerProtocol

    public init(
        queue: AnalyticsEventQueueProtocol,
        identity: AnalyticsIdentityProtocol,
        attestation: BackendAttestationProviderProtocol,
        uploadFactory: AnalyticsUploadOperationFactoryProtocol,
        operationQueue: OperationQueue,
        appVersion: String,
        timeProvider: @escaping () -> Date = { Date() },
        logger: SDKLoggerProtocol
    ) {
        self.queue = queue
        self.identity = identity
        self.attestation = attestation
        self.uploadFactory = uploadFactory
        self.operationQueue = operationQueue
        self.appVersion = appVersion
        self.timeProvider = timeProvider
        self.logger = logger
    }
}

// MARK: - Private

private extension AnalyticsUploader {
    enum Constants {
        static let batchSize = 50
        static let schemaVersion = 1
        static let platform = "ios"
    }

    enum BatchOutcome {
        case drained
        case stop
        case failed(Error)
    }

    struct Batch {
        let body: Data
        let ids: [String]
        let isFull: Bool
        let epoch: Int
    }

    func createBatchesWrapper(remaining: Int) -> CompoundOperationWrapper<BatchOutcome> {
        guard remaining > 0 else {
            return .createWithResult(.stop)
        }

        let batchWrapper = createBatchWrapper()

        let nextWrapper = OperationCombiningService<BatchOutcome>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                return .createWithResult(.stop)
            }

            let outcome: BatchOutcome

            do {
                outcome = try batchWrapper.targetOperation.extractNoCancellableResultData()
            } catch is AnalyticsUploadAbort {
                logger.debug("Analytics batch abandoned before it was built")

                return .createWithResult(.stop)
            } catch {
                return .createWithResult(.failed(error))
            }

            guard case .drained = outcome else {
                return .createWithResult(outcome)
            }

            return createBatchesWrapper(remaining: remaining - 1)
        }

        nextWrapper.addDependency(wrapper: batchWrapper)

        return nextWrapper.insertingHead(operations: batchWrapper.allOperations)
    }

    func createBatchWrapper() -> CompoundOperationWrapper<BatchOutcome> {
        let peekWrapper = queue.peekWrapper(count: Constants.batchSize)

        let sendWrapper = OperationCombiningService<BatchOutcome>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                return .createWithResult(.stop)
            }

            let rows: [AnalyticsPendingEvent]

            do {
                rows = try peekWrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                logger.error("Analytics queue is unreadable, clearing it: \(error)")

                return createClearWrapper(outcome: .stop)
            }

            guard !rows.isEmpty else {
                return .createWithResult(.stop)
            }

            return createSendWrapper(batch: try createBatch(rows: rows))
        }

        sendWrapper.addDependency(wrapper: peekWrapper)

        return sendWrapper.insertingHead(operations: peekWrapper.allOperations)
    }

    func createSendWrapper(batch: Batch) -> CompoundOperationWrapper<BatchOutcome> {
        let body = batch.body
        let epoch = batch.epoch

        let consentGate: () throws -> Void = { [weak self] in
            guard let self, identity.consentEpoch == epoch else {
                throw AnalyticsUploadAbort.consentWithdrawn
            }
        }

        let headersWrapper = attestation.createSignedHeadersWrapper {
            try consentGate()

            return body
        }

        let uploadOperation = uploadFactory.createUploadOperation(
            bodyClosure: {
                try consentGate()

                return body
            },
            headersClosure: { try headersWrapper.targetOperation.extractNoCancellableResultData() }
        )

        uploadOperation.addDependency(headersWrapper.targetOperation)

        let outcomeWrapper = OperationCombiningService<BatchOutcome>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                return .createWithResult(.stop)
            }

            do {
                try uploadOperation.extractNoCancellableResultData()
            } catch {
                return createFailureWrapper(error, batch: batch)
            }

            return createDropWrapper(batch: batch)
        }

        outcomeWrapper.addDependency(operations: [uploadOperation])

        return outcomeWrapper.insertingHead(
            operations: headersWrapper.allOperations + [uploadOperation]
        )
    }

    func createFailureWrapper(_ error: Error, batch: Batch) -> CompoundOperationWrapper<BatchOutcome> {
        if let transportError = error as? AnalyticsTransportError {
            switch transportError {
            case .rejected:
                logger.warning("Analytics upload rejected, clearing the queue: \(transportError)")
                attestation.markUnattested()

                return createClearWrapper(outcome: .failed(transportError))
            case .clientError:
                logger.warning("Analytics batch refused, dropping it: \(transportError)")

                return createDropWrapper(batch: batch)
            case .retryLater, .serverError:
                logger.debug("Analytics upload retained for a later flush: \(transportError)")

                return .createWithResult(.failed(transportError))
            }
        }

        if let attestationError = error as? BackendAttestationError, case .rejected = attestationError {
            logger.warning("Gateway refused registration, clearing the queue")

            return createClearWrapper(outcome: .failed(attestationError))
        }

        if error is AnalyticsUploadAbort {
            logger.debug("Analytics batch abandoned in flight")

            return .createWithResult(.stop)
        }

        logger.debug("Analytics upload retained for a later flush: \(error)")

        return .createWithResult(.failed(error))
    }

    func createDropWrapper(batch: Batch) -> CompoundOperationWrapper<BatchOutcome> {
        let operation = queue.dropOperation(ids: batch.ids)

        let mapOperation = ClosureOperation<BatchOutcome> {
            try operation.extractNoCancellableResultData()

            return batch.isFull ? .drained : .stop
        }

        mapOperation.addDependency(operation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [operation])
    }

    /// Clearing the queue is not delivery, so a rejection still has to grade as a failed flush.
    func createClearWrapper(outcome: BatchOutcome) -> CompoundOperationWrapper<BatchOutcome> {
        let operation = queue.clearOperation()

        let mapOperation = ClosureOperation<BatchOutcome> {
            try operation.extractNoCancellableResultData()

            return outcome
        }

        mapOperation.addDependency(operation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [operation])
    }

    func createBatch(rows: [AnalyticsPendingEvent]) throws -> Batch {
        let events = rows.compactMap { row -> AnalyticsEventRemote? in
            do {
                let props = try AnalyticsCoding.decoder.decode(
                    [String: AnalyticsPropertyValue].self,
                    from: row.payload
                )

                return AnalyticsEventRemote(
                    id: row.identifier,
                    name: row.name,
                    timestamp: ISO8601MillisFormatter.string(from: row.timestamp),
                    props: props
                )
            } catch {
                logger.error("Analytics row \(row.identifier) is undecodable, dropping it")

                return nil
            }
        }

        let epoch = identity.consentEpoch

        guard let installId = identity.installId(), identity.consentEpoch == epoch else {
            throw AnalyticsUploadAbort.consentWithdrawn
        }

        let envelope = AnalyticsEnvelope(
            schemaVersion: Constants.schemaVersion,
            platform: Constants.platform,
            appVersion: appVersion,
            installId: installId,
            sessionId: identity.sessionId,
            sentAt: ISO8601MillisFormatter.string(from: timeProvider()),
            events: events
        )

        return Batch(
            body: try AnalyticsCoding.encoder.encode(envelope),
            ids: rows.map(\.identifier),
            isFull: rows.count == Constants.batchSize,
            epoch: epoch
        )
    }
}

// MARK: - AnalyticsUploading

extension AnalyticsUploader: AnalyticsUploading {
    public func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void> {
        let batchesWrapper = createBatchesWrapper(remaining: maxBatches)

        let mapOperation = ClosureOperation<Void> {
            guard case let .failed(error) = try batchesWrapper
                .targetOperation
                .extractNoCancellableResultData()
            else {
                return
            }

            throw error
        }

        mapOperation.addDependency(batchesWrapper.targetOperation)

        return batchesWrapper.insertingTail(operation: mapOperation)
    }
}
