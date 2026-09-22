import Foundation
import Operation_iOS
import NovaOperationSupport
import SDKLogger

public final class BackendAttestationProvider {
    let appAttest: AppAttestServiceProtocol
    let remoteFactory: BackendAttestationRemoteFactoryProtocol
    let identity: BackendAttestationIdentityProtocol
    let repository: AnyDataProviderRepository<AppAttestKeySettings>
    let gatewayURL: URL
    let gatewayOrigin: String?
    let mode: BackendAttestationMode
    let appIdentity: AppAttestAppIdentity
    let operationQueue: OperationQueue
    let logger: SDKLoggerProtocol
    let timeProvider: () -> Date

    private let mutex = NSLock()

    private var attestedKeyId: AppAttestKeyId?
    private var rejectedForProcess: Bool = false
    private var invalidKeyIdDiscardedThisLaunch: Bool = false
    private var attestationGenericDiscardedThisLaunch: Bool = false
    private var unauthorizedDiscardedThisLaunch: Bool = false
    private var unattestedMarkedThisLaunch: Bool = false

    private var needsFreshKey: Bool = false

    public init(
        appAttest: AppAttestServiceProtocol,
        remoteFactory: BackendAttestationRemoteFactoryProtocol,
        identity: BackendAttestationIdentityProtocol,
        repository: AnyDataProviderRepository<AppAttestKeySettings>,
        gatewayURL: URL,
        mode: BackendAttestationMode,
        appIdentity: AppAttestAppIdentity,
        operationQueue: OperationQueue,
        logger: SDKLoggerProtocol,
        timeProvider: @escaping () -> Date = { Date() }
    ) {
        self.appAttest = appAttest
        self.remoteFactory = remoteFactory
        self.identity = identity
        self.repository = repository
        self.gatewayURL = gatewayURL
        gatewayOrigin = AttestationRequestTarget.origin(of: gatewayURL)
        self.mode = mode
        self.appIdentity = appIdentity
        self.operationQueue = operationQueue
        self.logger = logger
        self.timeProvider = timeProvider
    }
}

// MARK: - State

extension BackendAttestationProvider {
    // Each trigger gets one discard per launch so one failure cannot suppress another's recovery.
    enum DiscardBrake {
        case invalidKeyId
        case attestationGeneric
        case unauthorized
    }

    enum Constants {
        static let platform = "ios"
        static let attestationType = "app_attest"
        static let rejectedStatusCode = 403
        static let baseBackoff: TimeInterval = 60
        static let maxBackoff: TimeInterval = 86400
    }

    func rowIdentifier(for clientId: String) -> String {
        gatewayURL.absoluteString + "|" + clientId
    }

    func backoffInterval(for attemptCount: Int) -> TimeInterval {
        guard attemptCount > 1 else {
            return Constants.baseBackoff
        }

        let scaled = Constants.baseBackoff * pow(2, Double(attemptCount - 1))

        return min(scaled, Constants.maxBackoff)
    }

    // Ignore dates beyond the maximum backoff to recover from a clock moving backwards.
    func isBackoffActive(until nextAttemptAt: Date) -> Bool {
        let now = timeProvider()

        return nextAttemptAt > now && nextAttemptAt <= now.addingTimeInterval(Constants.maxBackoff)
    }

    func cachedAttestedKeyId() -> AppAttestKeyId? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return needsFreshKey ? nil : attestedKeyId
    }

    // Check the epoch under the lock so stale work cannot consume the current discard signal.
    func resolveRow(_ stored: AppAttestKeySettings?, epoch: Int) throws -> AppAttestKeySettings? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        try requireEpoch(epoch)

        guard needsFreshKey else {
            return stored
        }

        needsFreshKey = false

        return nil
    }

    func requireEpoch(_ epoch: Int) throws {
        guard identity.consentEpoch == epoch else {
            throw BackendAttestationError.unsupported
        }
    }

    // Retain the queued attempt's epoch so it cannot create an identity after consent changes.
    func createChainContext(epoch: Int) throws -> AttestationChainContext {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        try requireEpoch(epoch)

        guard !rejectedForProcess else {
            throw BackendAttestationError.rejected(statusCode: Constants.rejectedStatusCode)
        }

        guard let clientId = identity.clientId() else {
            throw BackendAttestationError.unsupported
        }

        return AttestationChainContext(
            clientId: clientId,
            rowIdentifier: rowIdentifier(for: clientId),
            epoch: epoch
        )
    }

    func cacheAttestedKeyId(_ keyId: AppAttestKeyId, epoch: Int) throws {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        try requireEpoch(epoch)

        attestedKeyId = keyId
        needsFreshKey = false
    }

    // The caller holds `mutex` across consent changes. Identity rejections reset with consent;
    // Apple's device-level failure limits remain in effect for this launch.
    private func clearGatewayBrakes() {
        rejectedForProcess = false
        unattestedMarkedThisLaunch = false
        unauthorizedDiscardedThisLaunch = false
        // Clear the cache with the row so a discarded key cannot be reused after consent changes.
        attestedKeyId = nil
        needsFreshKey = true
    }

    func deleteRow(_ identifier: String) {
        executeDelete(repository.saveOperation({ [] }, { [identifier] }))
    }

    // Cleanup can run after another consent cycle starts, so preserve the current identity's row.
    func deleteAllRows() {
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let deleteOperation = repository.saveOperation({ [] }, { [weak self] in
            let rows = try fetchOperation.extractNoCancellableResultData()

            guard let self else {
                return []
            }

            let currentIdentifier = identity.existingClientId().map { self.rowIdentifier(for: $0) }

            return rows.map(\.identifier).filter { $0 != currentIdentifier }
        })

        deleteOperation.addDependency(fetchOperation)

        executeDelete(deleteOperation, dependencies: [fetchOperation])
    }

    func executeDelete(_ operation: BaseOperation<Void>, dependencies: [Operation] = []) {
        execute(
            wrapper: CompoundOperationWrapper(targetOperation: operation, dependencies: dependencies),
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Attestation key delete failed: \(error)")
            }
        }
    }

    // Attested rows ignore backoff; incrementing their retry count would serve no purpose.
    func applyBackoff(_ context: AttestationChainContext, returningSpentKey: Bool = false) {
        guard identity.consentEpoch == context.epoch else {
            return
        }

        let identifier = context.rowIdentifier

        let fetchOperation = repository.fetchOperation(
            by: { identifier },
            options: RepositoryFetchOptions()
        )

        let saveOperation = repository.saveOperation({ [weak self] in
            guard
                let self,
                let row = try fetchOperation.extractNoCancellableResultData(),
                !row.isAttested
            else {
                return []
            }

            try requireEpoch(context.epoch)

            let attemptCount = row.attemptCount + 1

            return [
                AppAttestKeySettings(
                    identifier: row.identifier,
                    keyId: row.keyId,
                    isAttested: row.isAttested,
                    isAttestationSpent: returningSpentKey ? false : row.isAttestationSpent,
                    attemptCount: attemptCount,
                    nextAttemptAt: timeProvider().addingTimeInterval(backoffInterval(for: attemptCount))
                )
            ]
        }, { [] })

        saveOperation.addDependency(fetchOperation)

        let wrapper = CompoundOperationWrapper(
            targetOperation: saveOperation,
            dependencies: [fetchOperation]
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Attestation backoff write failed: \(error)")
            }
        }
    }

    // A client identifier cannot bind to a replacement key, so retire both together.
    func discardRowOnce(_ context: AttestationChainContext, brake: DiscardBrake) -> Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard identity.consentEpoch == context.epoch else {
            return false
        }

        let shouldDiscard: Bool

        switch brake {
        case .invalidKeyId:
            shouldDiscard = !invalidKeyIdDiscardedThisLaunch
            invalidKeyIdDiscardedThisLaunch = true
        case .attestationGeneric:
            shouldDiscard = !attestationGenericDiscardedThisLaunch
            attestationGenericDiscardedThisLaunch = true
        case .unauthorized:
            shouldDiscard = !unauthorizedDiscardedThisLaunch
            unauthorizedDiscardedThisLaunch = true
        }

        if shouldDiscard {
            attestedKeyId = nil
            needsFreshKey = true
        }

        guard shouldDiscard else {
            return false
        }

        identity.resetClientId(ifCurrent: context.clientId)
        deleteRow(context.rowIdentifier)

        return true
    }

    @discardableResult
    func handleFailure(_ error: Error, context: AttestationChainContext?) -> Bool {
        mutex.lock()

        guard let context, identity.consentEpoch == context.epoch else {
            mutex.unlock()

            return false
        }

        if let attestationError = error as? BackendAttestationError, case .rejected = attestationError {
            rejectedForProcess = true
            attestedKeyId = nil
            mutex.unlock()

            logger.warning("Gateway rejected this client; attestation short-circuits until relaunch")

            return false
        }

        mutex.unlock()

        if let serviceError = error as? AppAttestServiceError {
            return handleAppleFailure(serviceError, context: context)
        } else if let attestationError = error as? BackendAttestationError {
            return handleGatewayFailure(attestationError, context: context)
        }

        return false
    }

    func handleAppleFailure(_ error: AppAttestServiceError, context: AttestationChainContext) -> Bool {
        logger.warning("Attestation attempt failed in App Attest: \(error)")

        switch error {
        case .invalidKeyId:
            return logDisposition(
                discardRowOnce(context, brake: .invalidKeyId),
                retired: "key identifier refused, retiring the key and the client id",
                kept: "key identifier refused again this launch, keeping both until relaunch"
            )
        case .attestationGeneric:
            if !discardRowOnce(context, brake: .attestationGeneric) {
                logger.warning("attestKey failed again this launch; opening the persisted backoff")
                applyBackoff(context)

                return false
            }

            logger.warning("attestKey failed; retiring the key and the client id")

            return true
        case .serviceUnavailable:
            // No attestation was produced, so the unspent key can be reused.
            logger.warning("Apple was unavailable; the key stays unspent and waits out a backoff")
            applyBackoff(context, returningSpentKey: true)

            return false
        case .keyIdGeneration, .assertionGeneric:
            return false
        }
    }

    func handleGatewayFailure(_ error: BackendAttestationError, context: AttestationChainContext) -> Bool {
        logger.warning("Attestation attempt failed at the gateway: \(error)")

        switch error {
        case .unauthorized:
            // Back off after the launch's discard is spent to avoid generating a key on every flush.
            guard discardRowOnce(context, brake: .unauthorized) else {
                logger.warning("Gateway refused the identity again this launch; opening the backoff")
                applyBackoff(context)

                return false
            }

            logger.warning("Gateway refused the identity; retiring it and retrying once")

            return true
        case .clientError, .serverError:
            applyBackoff(context)

            return false
        case .rejected, .retryLater, .unsupported, .invalidResponse:
            return false
        }
    }

    func logDisposition(_ didRetire: Bool, retired: String, kept: String) -> Bool {
        logger.warning(didRetire ? retired : kept)

        return didRetire
    }

    func shouldRetryAfterRetiring(_ error: Error) -> Bool {
        guard let attestationError = error as? BackendAttestationError else {
            return false
        }

        guard case .unauthorized = attestationError else {
            return false
        }

        return true
    }

    func attestedKeyId(from row: AppAttestKeySettings?, epoch: Int) throws -> AppAttestKeyId? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        try requireEpoch(epoch)

        if !needsFreshKey, let cached = attestedKeyId {
            return cached
        }

        // A discard during the probe invalidates this snapshot; do not restore its rejected key.
        guard !needsFreshKey, let row, row.isAttested else {
            return nil
        }

        attestedKeyId = row.keyId

        return row.keyId
    }
}

// MARK: - Provider protocol

extension BackendAttestationProvider: BackendAttestationProviderProtocol {
    public func createSignedHeadersWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let contextBox = AttestationChainContextBox()
        let epoch = identity.consentEpoch

        let attemptWrapper = createAttemptWrapper(
            target: target,
            bodyClosure: bodyClosure,
            contextBox: contextBox,
            epoch: epoch
        )

        let retryWrapper = OperationCombiningService<[AttestationHeaderKey: String]?>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            do {
                let headers = try attemptWrapper.targetOperation.extractNoCancellableResultData()

                return .createWithResult(headers)
            } catch {
                // Retry once only after retiring the rejected identity.
                guard shouldRetryAfterRetiring(error), contextBox.didRetire else {
                    throw error
                }

                guard let context = contextBox.value else {
                    throw BackendAttestationError.unsupported
                }

                return createAttemptWrapper(
                    target: target,
                    bodyClosure: bodyClosure,
                    contextBox: AttestationChainContextBox(),
                    epoch: context.epoch
                )
            }
        }

        retryWrapper.addDependency(wrapper: attemptWrapper)

        return retryWrapper.insertingHead(operations: attemptWrapper.allOperations)
    }

    public func markUnattested(ifCurrentClientId clientId: String) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard identity.existingClientId() == clientId else {
            return
        }

        let shouldDiscard = !unattestedMarkedThisLaunch

        if shouldDiscard {
            unattestedMarkedThisLaunch = true
            attestedKeyId = nil
            needsFreshKey = true
        }

        guard shouldDiscard else {
            logger.warning("Events endpoint refused the assertion again; keeping the key until relaunch")

            return
        }

        identity.resetClientId(ifCurrent: clientId)
        deleteRow(rowIdentifier(for: clientId))
    }

    public func forgetClient() {
        mutex.lock()

        let clientId = identity.existingClientId()

        identity.forgetClientId()

        clearGatewayBrakes()

        mutex.unlock()

        if let clientId {
            deleteRow(rowIdentifier(for: clientId))
        } else {
            deleteAllRows()
        }
    }

    public func allowClient() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let clientId = identity.existingClientId()

        // A distinct row prevents writes prepared before consent changes from reaching the new identity.
        if let clientId {
            identity.resetClientId(ifCurrent: clientId)
        }

        identity.allowCreation()

        clearGatewayBrakes()

        if let clientId {
            deleteRow(rowIdentifier(for: clientId))
        }
    }
}
