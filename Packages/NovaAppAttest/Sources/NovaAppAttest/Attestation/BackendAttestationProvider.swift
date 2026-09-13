import Foundation
import Operation_iOS
import NovaOperationSupport
import SDKLogger

/// Holds one attested App Attest key per (gateway, clientId) row, and retires the client id with it —
/// the gateway never rebinds an id to a different key. Both are re-minted on a launch's first
/// invalid-identifier report, generic attestKey failure, identity-bearing 401 and events-endpoint
/// rejection, and on a consent cycle, which lifts the process-wide gateway rejection and both
/// gateway-verdict latches but not the two Apple brakes. A gateway client or server error,
/// serviceUnavailable and a repeat generic attestKey failure open the persisted backoff on an
/// un-attested row; anything else, a repeat invalid-identifier report included, waits on the flush
/// schedule. A 401 that retired the identity is retried once in the same request; the events
/// endpoint instead retains its batch and recovers on the next flush.
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
    /// Each trigger owns its own per-launch discard, so one spending its brake cannot silence another.
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

    /// The window is an absolute persisted date, so a clock moved backwards would wedge attestation for
    /// the whole shift; nothing this class wrote can sit further out than one full backoff.
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

    /// Checks the epoch while holding the lock that guards the one-shot discard, so a chain the
    /// consent cycle has already superseded cannot consume the signal armed for its successor.
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

    func cacheAttestedKeyId(_ keyId: AppAttestKeyId) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        attestedKeyId = keyId
        needsFreshKey = false
    }

    /// Both consent transitions mint an identity the gateway has never rejected, so its latches start over.
    /// Apple's verdict on a key describes the device, not the identity, so those brakes stay launch scoped.
    func clearGatewayBrakes() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        rejectedForProcess = false
        unattestedMarkedThisLaunch = false
        unauthorizedDiscardedThisLaunch = false
        // The persisted window a repeating 401 arms is gateway scoped too, so it starts over with
        // the rest: the row carrying it is ignored once, and the next attempt mints a fresh key
        // instead of waiting out a brake this consent cycle has already superseded. The cached key
        // goes with the flag — the credentials gate resolves the row before it reads the cache, so
        // a key left behind here would answer for a row that was just discarded.
        attestedKeyId = nil
        needsFreshKey = true
    }

    func deleteRow(_ identifier: String) {
        executeDelete(repository.saveOperation({ [] }, { [identifier] }))
    }

    /// An install owns one gateway client, so with no client id stored every remaining row is an orphan
    /// of an opt-out that cleared the id before its row delete ran.
    func deleteAllRows() {
        executeDelete(repository.deleteAllOperation())
    }

    func executeDelete(_ operation: BaseOperation<Void>) {
        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Attestation key delete failed: \(error)")
            }
        }
    }

    /// A no-op on an attested row: the gate stops reading `nextAttemptAt` once a key is attested, so a
    /// window there would only inflate `attemptCount`. The uploader's flush schedule is the brake there.
    func applyBackoff(_ context: AttestationChainContext, returningSpentKey: Bool = false) {
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

    /// Retires the key and the client id together. The gateway never rebinds an id to a different
    /// key, so a new key under the old id is refused as a conflict for as long as that install
    /// lives; the identity has to move with the key it was bound to.
    func discardRowOnce(_ context: AttestationChainContext, brake: DiscardBrake) -> Bool {
        mutex.lock()

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

        mutex.unlock()

        guard shouldDiscard else {
            return false
        }

        identity.resetClientId(ifCurrent: context.clientId)
        deleteRow(context.rowIdentifier)

        return true
    }

    /// Returns whether the identity was retired, which is what makes a retry worth running.
    @discardableResult
    func handleFailure(_ error: Error, context: AttestationChainContext?) -> Bool {
        if let attestationError = error as? BackendAttestationError, case .rejected = attestationError {
            mutex.lock()
            rejectedForProcess = true
            attestedKeyId = nil
            mutex.unlock()

            logger.warning("Gateway rejected this client; attestation short-circuits until relaunch")

            return false
        }

        guard let context else {
            return false
        }

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
            // Apple never produced an attestation, so the key is still unspent and the same one is
            // retried rather than discarded.
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
            // Once this launch has spent its discard, a repeating 401 would otherwise leave a spent
            // row with no window: every flush would then mint a fresh key and burn an attestKey call
            // on a rejection nothing has changed. Fall through to the same brake the other gateway
            // failures use.
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

    /// Says which way a discard went, so a log reader can tell a retirement from a spent brake.
    func logDisposition(_ didRetire: Bool, retired: String, kept: String) -> Bool {
        logger.warning(didRetire ? retired : kept)

        return didRetire
    }

    /// One retry per signing request, and only for the failure a fresh identity can actually fix.
    func shouldRetryAfterRetiring(_ error: Error) -> Bool {
        guard let attestationError = error as? BackendAttestationError else {
            return false
        }

        guard case .unauthorized = attestationError else {
            return false
        }

        return true
    }

    /// Whether the gateway has refused this installation for the rest of the process. The only
    /// reader is the chain, in another file, so the lock stays with the state it guards.
    var isRejectedForProcess: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return rejectedForProcess
    }

    /// The attested key this row names, remembering it so later requests in the process skip the
    /// repository entirely.
    func attestedKeyId(from row: AppAttestKeySettings?) -> AppAttestKeyId? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if !needsFreshKey, let cached = attestedKeyId {
            return cached
        }

        // The row was read before the probe went out. A discard that landed while it was in flight
        // retired exactly that row, so promoting the snapshot here would put the key the gateway
        // just refused straight back into service and clear the signal asking for a new one.
        guard !needsFreshKey, let row, row.isAttested else {
            return nil
        }

        attestedKeyId = row.keyId

        return row.keyId
    }
}

// MARK: - BackendAttestationProviderProtocol

extension BackendAttestationProvider: BackendAttestationProviderProtocol {
    public func createSignedHeadersWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let contextBox = AttestationChainContextBox()

        let attemptWrapper = createAttemptWrapper(
            target: target,
            bodyClosure: bodyClosure,
            contextBox: contextBox
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
                // Only worth a second attempt when the first one actually retired the identity the
                // gateway refused — otherwise this replays the request it just refused. Exactly one
                // more attempt, never a loop.
                guard shouldRetryAfterRetiring(error), contextBox.didRetire else {
                    throw error
                }

                return createAttemptWrapper(
                    target: target,
                    bodyClosure: bodyClosure,
                    contextBox: AttestationChainContextBox()
                )
            }
        }

        retryWrapper.addDependency(wrapper: attemptWrapper)

        return retryWrapper.insertingHead(operations: attemptWrapper.allOperations)
    }

    public func markUnattested() {
        guard let clientId = identity.existingClientId() else {
            logger.warning("Events endpoint refused the assertion while no client id was stored")

            return
        }

        mutex.lock()
        let shouldDiscard = !unattestedMarkedThisLaunch

        if shouldDiscard {
            unattestedMarkedThisLaunch = true
            attestedKeyId = nil
            needsFreshKey = true
        }

        mutex.unlock()

        guard shouldDiscard else {
            logger.warning("Events endpoint refused the assertion again; keeping the key until relaunch")

            return
        }

        identity.resetClientId(ifCurrent: clientId)
        deleteRow(rowIdentifier(for: clientId))
    }

    public func forgetClient() {
        let clientId = identity.existingClientId()

        mutex.lock()
        attestedKeyId = nil
        needsFreshKey = true
        mutex.unlock()

        clearGatewayBrakes()

        identity.forgetClientId()

        if let clientId {
            deleteRow(rowIdentifier(for: clientId))
        } else {
            deleteAllRows()
        }
    }

    public func allowClient() {
        identity.allowCreation()

        clearGatewayBrakes()
    }
}
