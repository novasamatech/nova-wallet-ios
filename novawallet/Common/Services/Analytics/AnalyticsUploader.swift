import Foundation
import Operation_iOS

/// peek → sign → POST → drop, repeated while the gateway keeps accepting batches.
/// A batch is dropped only after its 2xx, so delivery is at-least-once (spec §6.3).
/// Thrown when consent is withdrawn while an upload chain is already executing, which
/// `flushCallStore.cancel()` cannot stop. Ends the chain instead of minting a replacement id.
enum AnalyticsUploadAbort: Error {
    case consentWithdrawn
}

final class AnalyticsUploader {
    private let queue: AnalyticsEventQueueProtocol
    private let identity: AnalyticsIdentityProtocol
    private let attestation: BackendAttestationProviderProtocol
    private let uploadFactory: AnalyticsUploadOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let appVersion: String
    private let timeProvider: () -> Date
    private let logger: LoggerProtocol

    init(
        queue: AnalyticsEventQueueProtocol,
        identity: AnalyticsIdentityProtocol,
        attestation: BackendAttestationProviderProtocol,
        uploadFactory: AnalyticsUploadOperationFactoryProtocol,
        operationQueue: OperationQueue,
        appVersion: String,
        timeProvider: @escaping () -> Date = { Date() },
        logger: LoggerProtocol = Logger.shared
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
        /// The batch was full, so there may be more rows waiting.
        case drained
        case stop
    }

    struct Batch {
        let body: Data
        let ids: [String]
        let isFull: Bool
    }

    func createBatchesWrapper(remaining: Int) -> CompoundOperationWrapper<Void> {
        guard remaining > 0 else {
            return .createWithResult(())
        }

        let batchWrapper = createBatchWrapper()

        let nextWrapper = OperationCombiningService<Void>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard
                let self,
                case .drained = try batchWrapper.targetOperation.extractNoCancellableResultData()
            else {
                return .createWithResult(())
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

            let rows = try peekWrapper.targetOperation.extractNoCancellableResultData()

            guard !rows.isEmpty else {
                return .createWithResult(.stop)
            }

            // Encoded once, here: the same value is handed to the signer and to the
            // request, so the bytes signed are the bytes sent.
            return createSendWrapper(batch: try createBatch(rows: rows))
        }

        sendWrapper.addDependency(wrapper: peekWrapper)

        return sendWrapper.insertingHead(operations: peekWrapper.allOperations)
    }

    func createSendWrapper(batch: Batch) -> CompoundOperationWrapper<BatchOutcome> {
        let body = batch.body

        let headersWrapper = attestation.createSignedHeadersWrapper { body }

        let uploadOperation = uploadFactory.createUploadOperation(
            bodyClosure: { body },
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

    /// Spec §6.3's outcome table, minus the 2xx row.
    func createFailureWrapper(_ error: Error, batch: Batch) -> CompoundOperationWrapper<BatchOutcome> {
        if let transportError = error as? AnalyticsTransportError {
            switch transportError {
            case .rejected:
                // The gateway no longer knows this identity. The next flush attests a
                // new key and re-registers; these events are gone.
                logger.warning("Analytics upload rejected, clearing the queue: \(transportError)")
                attestation.markUnattested()

                return createClearWrapper()
            case .clientError:
                logger.warning("Analytics batch refused, dropping it: \(transportError)")

                return createDropWrapper(batch: batch)
            case .serverError:
                logger.debug("Analytics upload stopped: \(transportError)")

                return .createWithResult(.stop)
            }
        }

        if let attestationError = error as? BackendAttestationError, case .rejected = attestationError {
            // Registration was refused for this whole process: nothing to re-attest.
            logger.warning("Gateway refused registration, clearing the queue")

            return createClearWrapper()
        }

        // 5xx, transport, serviceUnavailable and encoding failures keep the queue.
        logger.debug("Analytics upload stopped: \(error)")

        return .createWithResult(.stop)
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

    func createClearWrapper() -> CompoundOperationWrapper<BatchOutcome> {
        let operation = queue.clearOperation()

        let mapOperation = ClosureOperation<BatchOutcome> {
            try operation.extractNoCancellableResultData()

            return .stop
        }

        mapOperation.addDependency(operation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [operation])
    }

    /// `installId()` is called here and nowhere else, so the first flush is the first
    /// moment an identity exists.
    func createBatch(rows: [AnalyticsPendingEvent]) throws -> Batch {
        let events = rows.compactMap { row -> AnalyticsEventRemote? in
            do {
                let props = try AnalyticsCoding.decoder.decode(
                    [String: AnalyticsPropertyValue].self,
                    from: row.payload
                )

                return AnalyticsEventRemote(
                    name: row.name,
                    ts: ISO8601MillisFormatter.string(from: row.timestamp),
                    props: props
                )
            } catch {
                // Poison: it leaves with the batch instead of wedging the queue forever.
                logger.error("Analytics row \(row.identifier) is undecodable, dropping it")

                return nil
            }
        }

        // Opt-out during an in-flight flush deletes the id and blocks re-creation. There is
        // no batch to send without one, and minting a replacement is exactly the resurrection
        // spec 6.5 forbids.
        guard let installId = identity.installId() else {
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
            isFull: rows.count == Constants.batchSize
        )
    }
}

// MARK: - AnalyticsUploading

extension AnalyticsUploader: AnalyticsUploading {
    func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void> {
        createBatchesWrapper(remaining: maxBatches)
    }
}
