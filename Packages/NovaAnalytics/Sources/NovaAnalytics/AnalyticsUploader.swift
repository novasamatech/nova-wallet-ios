import Foundation
import Operation_iOS
import SDKLogger
import NovaAppAttest
import NovaOperationSupport

public enum AnalyticsUploadAbort: Error {
    case consentWithdrawn
}

// peek → sign → POST → drop, repeated while the destination keeps accepting batches.
public final class AnalyticsUploader {
    private let queue: AnalyticsEventQueueProtocol
    private let identity: AnalyticsIdentityProtocol
    private let gatewayResolver: AnalyticsGatewayResolving
    private let operationQueue: OperationQueue
    private let appVersion: String
    private let timeProvider: () -> Date
    private let logger: SDKLoggerProtocol

    // Internal: the gateway resolver it takes is an implementation detail of this package.
    init(
        queue: AnalyticsEventQueueProtocol,
        identity: AnalyticsIdentityProtocol,
        gatewayResolver: AnalyticsGatewayResolving,
        operationQueue: OperationQueue,
        appVersion: String,
        timeProvider: @escaping () -> Date = { Date() },
        logger: SDKLoggerProtocol
    ) {
        self.queue = queue
        self.identity = identity
        self.gatewayResolver = gatewayResolver
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

    // Only rows from the current consent epoch may upload.
    struct Page {
        let rows: [AnalyticsPendingEvent]
        let dropIds: [String]
        let isFull: Bool
        let epoch: Int
    }

    func createBatchesWrapper(remaining: Int, gateway: AnalyticsGateway) -> CompoundOperationWrapper<BatchOutcome> {
        guard remaining > 0 else {
            return .createWithResult(.stop)
        }

        let batchWrapper = createBatchWrapper(gateway: gateway)

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

            return createBatchesWrapper(remaining: remaining - 1, gateway: gateway)
        }

        nextWrapper.addDependency(wrapper: batchWrapper)

        return nextWrapper.insertingHead(operations: batchWrapper.allOperations)
    }

    func createBatchWrapper(gateway: AnalyticsGateway) -> CompoundOperationWrapper<BatchOutcome> {
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

                return createClearWrapper()
            }

            guard !rows.isEmpty else {
                return .createWithResult(.stop)
            }

            let page = selectPage(rows: rows)
            let events = vetRows(page.rows)

            guard !events.isEmpty else {
                logger.debug("Analytics page holds nothing sendable, dropping it unsent")

                return createDropWrapper(ids: page.dropIds, isFull: page.isFull)
            }

            return try createSendWrapper(batch: createBatch(events: events, page: page), gateway: gateway)
        }

        sendWrapper.addDependency(wrapper: peekWrapper)

        return sendWrapper.insertingHead(operations: peekWrapper.allOperations)
    }

    func createSendWrapper(batch: Batch, gateway: AnalyticsGateway) throws -> CompoundOperationWrapper<BatchOutcome> {
        let body = batch.body
        let epoch = batch.epoch
        let target = try gateway.uploadFactory.eventsTarget()

        let consentGate: () throws -> Void = { [weak self] in
            guard let self, identity.consentEpoch == epoch else {
                throw AnalyticsUploadAbort.consentWithdrawn
            }
        }

        let headersWrapper = gateway.attestation.createSignedHeadersWrapper(target: target) {
            try consentGate()

            return body
        }

        let uploadOperation = gateway.uploadFactory.createUploadOperation(
            target: target,
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
                let signedClientId = try? headersWrapper.targetOperation
                    .extractNoCancellableResultData()?[.clientId]

                return createFailureWrapper(error, batch: batch, signedClientId: signedClientId, gateway: gateway)
            }

            return createDropWrapper(batch: batch)
        }

        outcomeWrapper.addDependency(operations: [uploadOperation])

        return outcomeWrapper.insertingHead(
            operations: headersWrapper.allOperations + [uploadOperation]
        )
    }

    // Keep batches for identity errors; discard only permanently rejected payloads.
    func createFailureWrapper(
        _ error: Error,
        batch: Batch,
        signedClientId: String?,
        gateway: AnalyticsGateway
    ) -> CompoundOperationWrapper<BatchOutcome> {
        if let transportError = error as? AnalyticsTransportError {
            switch transportError {
            case .rejected:
                logger.warning("Analytics upload rejected, retaining the batch: \(transportError)")

                if let signedClientId {
                    gateway.attestation.markUnattested(ifCurrentClientId: signedClientId)
                }

                return .createWithResult(.failed(transportError))
            case .clientError:
                logger.warning("Analytics batch refused, dropping it: \(transportError)")

                return createDropWrapper(batch: batch)
            case .proofRefused:
                logger.warning("Analytics proof refused, retaining the batch: \(transportError)")

                return .createWithResult(.failed(transportError))
            case .retryLater, .serverError:
                logger.debug("Analytics upload retained for a later flush: \(transportError)")

                return .createWithResult(.failed(transportError))
            }
        }

        if let attestationError = error as? BackendAttestationError, case .rejected = attestationError {
            logger.warning("Gateway refused registration, retaining the batch")

            return .createWithResult(.failed(attestationError))
        }

        if error is AnalyticsUploadAbort {
            logger.debug("Analytics batch abandoned in flight")

            return .createWithResult(.stop)
        }

        logger.debug("Analytics upload retained for a later flush: \(error)")

        return .createWithResult(.failed(error))
    }

    func createDropWrapper(batch: Batch) -> CompoundOperationWrapper<BatchOutcome> {
        createDropWrapper(ids: batch.ids, isFull: batch.isFull)
    }

    func createDropWrapper(ids: [String], isFull: Bool) -> CompoundOperationWrapper<BatchOutcome> {
        let operation = queue.dropOperation(ids: ids)

        let mapOperation = ClosureOperation<BatchOutcome> {
            try operation.extractNoCancellableResultData()

            return isFull ? .drained : .stop
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

    func selectPage(rows: [AnalyticsPendingEvent]) -> Page {
        let epoch = identity.consentEpoch
        let current = rows.filter { $0.consentEpoch == epoch }

        if current.count < rows.count {
            logger.debug("Analytics rows from an earlier consent epoch dropped: \(rows.count - current.count)")
        }

        return Page(
            rows: current,
            dropIds: rows.map(\.identifier),
            isFull: rows.count == Constants.batchSize,
            epoch: epoch
        )
    }

    func vetRows(_ rows: [AnalyticsPendingEvent]) -> [AnalyticsEventRemote] {
        rows.compactMap { row -> AnalyticsEventRemote? in
            do {
                return try AnalyticsWirePayloadPolicy.vet(row)
            } catch {
                logger.error("Analytics row \(row.identifier) is unsendable, dropping it")

                return nil
            }
        }
    }

    func createBatch(events: [AnalyticsEventRemote], page: Page) throws -> Batch {
        let epoch = page.epoch

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
            ids: page.dropIds,
            isFull: page.isFull,
            epoch: epoch
        )
    }
}

// MARK: - AnalyticsUploading

extension AnalyticsUploader: AnalyticsUploading {
    /// The infra URL heads the chain: nothing can be signed or posted before it resolves, and a
    /// failure to resolve it is retained like any other flush failure, so the queue survives it.
    public func flushWrapper(maxBatches: Int) -> CompoundOperationWrapper<Void> {
        let gatewayWrapper = gatewayResolver.createGatewayWrapper()

        let batchesWrapper = OperationCombiningService<BatchOutcome>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                return .createWithResult(.stop)
            }

            let gateway = try gatewayWrapper.targetOperation.extractNoCancellableResultData()

            return createBatchesWrapper(remaining: maxBatches, gateway: gateway)
        }

        batchesWrapper.addDependency(wrapper: gatewayWrapper)

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

        return batchesWrapper
            .insertingHead(operations: gatewayWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }
}
