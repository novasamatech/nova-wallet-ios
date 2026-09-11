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
    private let appAttest: AppAttestServiceProtocol
    private let remoteFactory: BackendAttestationRemoteFactoryProtocol
    private let identity: BackendAttestationIdentityProtocol
    private let repository: AnyDataProviderRepository<AppAttestKeySettings>
    private let gatewayURL: URL
    private let gatewayOrigin: String?
    private let mode: BackendAttestationMode
    private let appIdentity: AppAttestAppIdentity
    private let operationQueue: OperationQueue
    private let logger: SDKLoggerProtocol
    private let timeProvider: () -> Date

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

/// The row a running chain owns, so the failure handler never asks the identity for a client id —
/// that call mints one.
private struct AttestationChainContext {
    let clientId: String
    let rowIdentifier: String
    let epoch: Int
}

private final class AttestationChainContextBox {
    private let mutex = NSLock()
    private var stored: AttestationChainContext?
    private var retired: Bool = false

    var value: AttestationChainContext? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return stored
    }

    /// Whether this attempt's failure actually retired the identity. Retrying without that is a
    /// second run of the byte-identical request the gateway just refused.
    var didRetire: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return retired
    }

    func store(_ context: AttestationChainContext) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        stored = context
    }

    func markRetired() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        retired = true
    }
}

// MARK: - State

private extension BackendAttestationProvider {
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

    func resolveRow(_ stored: AppAttestKeySettings?) -> AppAttestKeySettings? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

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
        switch error {
        case .invalidKeyId:
            return discardRowOnce(context, brake: .invalidKeyId)
        case .attestationGeneric:
            if !discardRowOnce(context, brake: .attestationGeneric) {
                applyBackoff(context)

                return false
            }

            return true
        case .serviceUnavailable:
            // Apple never produced an attestation, so the key is still unspent and the same one is
            // retried rather than discarded.
            applyBackoff(context, returningSpentKey: true)

            return false
        case .keyIdGeneration, .assertionGeneric:
            return false
        }
    }

    func handleGatewayFailure(_ error: BackendAttestationError, context: AttestationChainContext) -> Bool {
        switch error {
        case .unauthorized:
            return discardRowOnce(context, brake: .unauthorized)
        case .clientError, .serverError:
            applyBackoff(context)

            return false
        case .rejected, .retryLater, .unsupported, .invalidResponse:
            return false
        }
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
}

// MARK: - Chain

private extension BackendAttestationProvider {
    /// One full signing attempt. `contextBox` carries out what its failure handler learned: which
    /// identity ran, and whether that identity was retired.
    func createAttemptWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data,
        contextBox: AttestationChainContextBox
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let wrapper = OperationCombiningService<[AttestationHeaderKey: String]?>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            return createHeadersWrapper(
                target: target,
                bodyClosure: bodyClosure,
                contextBox: contextBox
            )
        }

        let resultOperation = ClosureOperation<[AttestationHeaderKey: String]?> { [weak self] in
            do {
                return try wrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                if self?.handleFailure(error, context: contextBox.value) == true {
                    contextBox.markRetired()
                }

                throw error
            }
        }

        resultOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: resultOperation)
    }

    func createHeadersWrapper(
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data,
        contextBox: AttestationChainContextBox
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        mutex.lock()
        let isRejected = rejectedForProcess
        mutex.unlock()

        guard !isRejected else {
            return .createWithError(
                BackendAttestationError.rejected(statusCode: Constants.rejectedStatusCode)
            )
        }

        switch mode {
        case .unavailable:
            return .createWithError(BackendAttestationError.unsupported)
        case .appAttest:
            break
        }

        // The proof does not name its destination yet, so refusing an off-gateway target here is
        // what keeps an assertion minted for this client from being spent against another host.
        guard let gatewayOrigin else {
            logger.error("Gateway URL \(gatewayURL) has no canonical origin; nothing can be attested")

            return .createWithError(BackendAttestationError.unsupported)
        }

        guard target.origin == gatewayOrigin else {
            logger.error("Refusing to attest a request for \(target.origin)")

            return .createWithError(BackendAttestationError.unsupported)
        }

        let epoch = identity.consentEpoch

        guard let clientId = identity.clientId(), identity.consentEpoch == epoch else {
            return .createWithError(BackendAttestationError.unsupported)
        }

        let context = AttestationChainContext(
            clientId: clientId,
            rowIdentifier: rowIdentifier(for: clientId),
            epoch: epoch
        )

        contextBox.store(context)

        return createSignedChainWrapper(
            clientId: clientId,
            context: context,
            target: target,
            bodyClosure: bodyClosure
        )
    }

    func createSignedChainWrapper(
        clientId: String,
        context: AttestationChainContext,
        target: AttestationRequestTarget,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let attestedWrapper = ensureAttestedWrapper(clientId: clientId, context: context)

        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try attestedWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return remoteFactory.createChallengeWrapper(clientId: clientId, purpose: .request)
        }

        challengeWrapper.addDependency(wrapper: attestedWrapper)

        let assertionWrapper = OperationCombiningService<AppAttestAssertion>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, appAttest] in
            let keyId = try attestedWrapper.targetOperation.extractNoCancellableResultData()
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return appAttest.createAssertionWrapper(keyId: keyId) {
                let body = try bodyClosure()

                return AttestationProfile2.preimage(
                    purpose: .request,
                    challenge: challenge,
                    clientId: clientId,
                    target: target,
                    bodyDigest: AttestationProfile2.bodyDigest(body)
                )
            }
        }

        assertionWrapper.addDependency(wrapper: challengeWrapper)

        let mapOperation = ClosureOperation<[AttestationHeaderKey: String]?> {
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()
            let assertion = try assertionWrapper.targetOperation.extractNoCancellableResultData()

            return [
                .profile: String(AttestationProfile2.version),
                .clientId: clientId,
                .challenge: challenge,
                .appAttestAssertion: assertion.base64EncodedString()
            ]
        }

        mapOperation.addDependency(assertionWrapper.targetOperation)

        return assertionWrapper
            .insertingHead(operations: attestedWrapper.allOperations + challengeWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }

    func ensureAttestedWrapper(
        clientId: String,
        context: AttestationChainContext
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        let identifier = context.rowIdentifier

        let fetchOperation = repository.fetchOperation(
            by: { identifier },
            options: RepositoryFetchOptions()
        )

        let wrapper = OperationCombiningService<AppAttestKeyId>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            if let cached = cachedAttestedKeyId() {
                return .createWithResult(cached)
            }

            let row = try resolveRow(fetchOperation.extractNoCancellableResultData())

            if let row, row.isAttested {
                cacheAttestedKeyId(row.keyId)

                return .createWithResult(row.keyId)
            }

            if let nextAttemptAt = row?.nextAttemptAt, isBackoffActive(until: nextAttemptAt) {
                throw BackendAttestationError.retryLater(until: nextAttemptAt)
            }

            try requireEpoch(context.epoch)

            // Apple attests a key once: a row whose attestation was already spent needs a new
            // key, not a second attestKey call that can only fail.
            let reusableKeyId = row?.isAttestationSpent == true ? nil : row?.keyId

            return createAttestAndRegisterWrapper(
                clientId: clientId,
                context: context,
                existingKeyId: reusableKeyId
            )
        }

        wrapper.addDependency(operations: [fetchOperation])

        return wrapper.insertingHead(operations: [fetchOperation])
    }

    func createAttestAndRegisterWrapper(
        clientId: String,
        context: AttestationChainContext,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        let keyIdWrapper = createKeyIdWrapper(context: context, existingKeyId: existingKeyId)

        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try keyIdWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return remoteFactory.createChallengeWrapper(clientId: clientId, purpose: .register)
        }

        challengeWrapper.addDependency(wrapper: keyIdWrapper)

        let markSpentOperation = createSaveOperation(
            isAttested: false,
            isAttestationSpent: true,
            context: context
        ) {
            try keyIdWrapper.targetOperation.extractNoCancellableResultData()
        }

        markSpentOperation.addDependency(challengeWrapper.targetOperation)

        let attestationWrapper = createAttestationWrapper(
            clientId: clientId,
            context: context,
            keyIdWrapper: keyIdWrapper,
            challengeWrapper: challengeWrapper
        )

        attestationWrapper.addDependency(wrapper: challengeWrapper)
        attestationWrapper.addDependency(operations: [markSpentOperation])

        let registerOperation = createRegisterOperation(
            clientId: clientId,
            context: context,
            challengeWrapper: challengeWrapper,
            attestationWrapper: attestationWrapper
        )

        registerOperation.addDependency(attestationWrapper.targetOperation)

        let saveAttestedOperation = createSaveOperation(
            isAttested: true,
            isAttestationSpent: true,
            context: context
        ) {
            try registerOperation.extractNoCancellableResultData()

            return try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
        }

        saveAttestedOperation.addDependency(registerOperation)

        let mapOperation = createCacheOperation(
            context: context,
            attestationWrapper: attestationWrapper,
            saveOperation: saveAttestedOperation
        )

        mapOperation.addDependency(saveAttestedOperation)

        let dependencies = keyIdWrapper.allOperations + challengeWrapper.allOperations +
            [markSpentOperation] + attestationWrapper.allOperations +
            [registerOperation, saveAttestedOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    /// Apple offers no way to look a key identifier up again, so a freshly minted one is written
    /// before it is attested — otherwise a failed attestation orphans a production key for good.
    func createKeyIdWrapper(
        context: AttestationChainContext,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        if let existingKeyId {
            return .createWithResult(existingKeyId)
        }

        let generationOperation = appAttest.createKeyGenerationOperation()

        let saveOperation = createSaveOperation(
            isAttested: false,
            isAttestationSpent: false,
            context: context
        ) {
            try generationOperation.extractNoCancellableResultData()
        }

        saveOperation.addDependency(generationOperation)

        let mapOperation = ClosureOperation<AppAttestKeyId> {
            try saveOperation.extractNoCancellableResultData()

            return try generationOperation.extractNoCancellableResultData()
        }

        mapOperation.addDependency(saveOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: [generationOperation, saveOperation]
        )
    }

    func createAttestationWrapper(
        clientId: String,
        context: AttestationChainContext,
        keyIdWrapper: CompoundOperationWrapper<AppAttestKeyId>,
        challengeWrapper: CompoundOperationWrapper<String>
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        OperationCombiningService<AppAttestAttestation>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, appAttest, remoteFactory] in
            let keyId = try keyIdWrapper.targetOperation.extractNoCancellableResultData()
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            // The registration proof commits to the register POST itself, and carries the binding
            // digest where a protected request carries its body digest.
            let target = try remoteFactory.registerTarget()
            let identity = appIdentity

            return appAttest.createAttestationWrapper(using: keyId) { attestingKeyId in
                AttestationProfile2.preimage(
                    purpose: .register,
                    challenge: challenge,
                    clientId: clientId,
                    target: target,
                    bodyDigest: AttestationProfile2.registrationDigest(
                        platform: Constants.platform,
                        appId: identity.appId,
                        attestationType: Constants.attestationType,
                        keyReference: attestingKeyId,
                        appAttestEnvironment: identity.environment
                    )
                )
            }
        }
    }

    func createRegisterOperation(
        clientId: String,
        context: AttestationChainContext,
        challengeWrapper: CompoundOperationWrapper<String>,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>
    ) -> BaseOperation<Void> {
        remoteFactory.createRegisterOperation { [weak self] in
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()
            let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            return BackendAttestationRegisterRequest(
                profile: AttestationProfile2.version,
                clientId: clientId,
                challenge: challenge,
                platform: Constants.platform,
                appId: appIdentity.appId,
                attestationType: Constants.attestationType,
                keyReference: attestation.keyId,
                appAttestEnvironment: appIdentity.environment,
                integrityToken: attestation.attestation.base64EncodedString()
            )
        }
    }

    func createCacheOperation(
        context: AttestationChainContext,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
        saveOperation: BaseOperation<Void>
    ) -> BaseOperation<AppAttestKeyId> {
        ClosureOperation<AppAttestKeyId> { [weak self] in
            try saveOperation.extractNoCancellableResultData()

            let keyId = try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(context.epoch)

            cacheAttestedKeyId(keyId)

            return keyId
        }
    }

    func createSaveOperation(
        isAttested: Bool,
        isAttestationSpent: Bool,
        context: AttestationChainContext,
        keyIdClosure: @escaping () throws -> AppAttestKeyId
    ) -> BaseOperation<Void> {
        let identifier = context.rowIdentifier

        return repository.saveOperation({ [weak self] in
            let keyId = try keyIdClosure()

            guard let self else {
                return []
            }

            try requireEpoch(context.epoch)

            return [
                AppAttestKeySettings(
                    identifier: identifier,
                    keyId: keyId,
                    isAttested: isAttested,
                    isAttestationSpent: isAttestationSpent,
                    attemptCount: 0,
                    nextAttemptAt: nil
                )
            ]
        }, { [] })
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
