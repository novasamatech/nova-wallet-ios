import Foundation
import Operation_iOS

/// Attest once, assert per request. Written fresh rather than generalised from the
/// deleted `DAppAttestationProvider`: that type's UUID-keyed coalescing existed for
/// concurrent browser calls, while the uploader is single-flight with serial batches,
/// so this is a straight wrapper chain plus a little state.
final class BackendAttestationProvider {
    private let appAttest: AppAttestServiceProtocol
    private let remoteFactory: BackendAttestationRemoteFactoryProtocol
    private let identity: BackendAttestationIdentityProtocol
    private let repository: AnyDataProviderRepository<AppAttestKeySettings>
    private let gatewayURL: URL
    private let mode: BackendAttestationMode
    private let bundle: Bundle
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol

    private let mutex = NSLock()

    private var attestedKeyId: AppAttestKeyId?
    private var rejectedForProcess: Bool = false
    private var invalidKeyIdDiscardedThisLaunch: Bool = false

    /// Covers the window between a recovery and its asynchronous row delete: while it is
    /// set the persisted row is ignored, so recovery can never re-attest the old key.
    private var needsFreshKey: Bool = false

    init(
        appAttest: AppAttestServiceProtocol,
        remoteFactory: BackendAttestationRemoteFactoryProtocol,
        identity: BackendAttestationIdentityProtocol,
        repository: AnyDataProviderRepository<AppAttestKeySettings>,
        gatewayURL: URL,
        mode: BackendAttestationMode,
        bundle: Bundle = .main,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.appAttest = appAttest
        self.remoteFactory = remoteFactory
        self.identity = identity
        self.repository = repository
        self.gatewayURL = gatewayURL
        self.mode = mode
        self.bundle = bundle
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

// MARK: - State

private extension BackendAttestationProvider {
    enum Constants {
        static let platform = "ios"
        static let attestationType = "app_attest"
        /// The short-circuit reports the canonical "client refused" code of spec §7.6;
        /// only the case, never the number, drives behaviour.
        static let rejectedStatusCode = 403
    }

    /// The key row is scoped to the gateway, so a host change starts a new credential.
    var rowIdentifier: String {
        gatewayURL.absoluteString
    }

    func cachedAttestedKeyId() -> AppAttestKeyId? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return needsFreshKey ? nil : attestedKeyId
    }

    /// Consumes `needsFreshKey`, so the first read after a recovery always attests anew.
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

    /// The only consent re-check the chain is allowed to make. `identity.clientId()` mints,
    /// so calling it as a predicate writes a fresh client id during an opt-out→re-consent
    /// race and then registers the *old* one; comparing epochs has no side effect.
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

    func invalidate() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        attestedKeyId = nil
        needsFreshKey = true
    }

    func deleteRow() {
        let identifier = rowIdentifier
        let operation = repository.saveOperation({ [] }, { [identifier] })

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.logger.error("Attestation key row delete failed: \(error)")
            }
        }
    }

    /// Spec §7.4's recovery table. Anything not listed — 5xx, transport,
    /// `serviceUnavailable` — keeps every piece of state.
    func handleFailure(_ error: Error) {
        if let attestationError = error as? BackendAttestationError, case .rejected = attestationError {
            mutex.lock()
            rejectedForProcess = true
            attestedKeyId = nil
            mutex.unlock()

            logger.warning("Gateway rejected this client; attestation short-circuits until relaunch")

            return
        }

        guard let serviceError = error as? AppAttestServiceError, case .invalidKeyId = serviceError else {
            return
        }

        mutex.lock()
        let shouldDiscard = !invalidKeyIdDiscardedThisLaunch

        if shouldDiscard {
            invalidKeyIdDiscardedThisLaunch = true
            attestedKeyId = nil
            needsFreshKey = true
        }

        mutex.unlock()

        guard shouldDiscard else {
            // A second invalidKeyId must not loop into endless key generation.
            return
        }

        deleteRow()
    }
}

// MARK: - Chain

private extension BackendAttestationProvider {
    func createHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
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
        case .none:
            return .createWithResult(nil)
        case .unavailable:
            return .createWithError(BackendAttestationError.unsupported)
        case .appAttest:
            break
        }

        // Same reason as the uploader's install id: never register a fresh attested client
        // for an install that has opted out while this chain was already executing. The
        // epoch captured here is what every later step compares against.
        //
        // Read epoch → id → epoch: `clientId()` and `consentEpoch` are two separate
        // acquisitions of the identity's lock, so an opt-out landing between them would
        // otherwise pair a forgotten client id with the epoch that forgot it, and every
        // later gate would wave the chain through.
        let epoch = identity.consentEpoch

        guard let clientId = identity.clientId(), identity.consentEpoch == epoch else {
            return .createWithError(BackendAttestationError.unsupported)
        }

        return createSignedChainWrapper(
            clientId: clientId,
            epoch: epoch,
            bodyClosure: bodyClosure
        )
    }

    func createSignedChainWrapper(
        clientId: String,
        epoch: Int,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let attestedWrapper = ensureAttestedWrapper(clientId: clientId, epoch: epoch)

        // A fresh challenge per signed request: never cached, never reused (spec §7.5).
        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, remoteFactory] in
            _ = try attestedWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(epoch)

            return remoteFactory.createChallengeWrapper()
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

            try requireEpoch(epoch)

            return appAttest.createAssertionWrapper(keyId: keyId) {
                let body = try bodyClosure()

                return AttestationClientData.assertionClientData(
                    challenge: challenge,
                    clientId: clientId,
                    body: body
                )
            }
        }

        assertionWrapper.addDependency(wrapper: challengeWrapper)

        let mapOperation = ClosureOperation<[AttestationHeaderKey: String]?> {
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()
            let assertion = try assertionWrapper.targetOperation.extractNoCancellableResultData()

            return [
                .clientId: clientId,
                .challenge: challenge,
                .signature: assertion.base64EncodedString()
            ]
        }

        mapOperation.addDependency(assertionWrapper.targetOperation)

        return assertionWrapper
            .insertingHead(operations: attestedWrapper.allOperations + challengeWrapper.allOperations)
            .insertingTail(operation: mapOperation)
    }

    func ensureAttestedWrapper(clientId: String, epoch: Int) -> CompoundOperationWrapper<AppAttestKeyId> {
        let fetchOperation = repository.fetchOperation(
            by: { self.rowIdentifier },
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

            // The client id was read before this chain started. Opting out since then bumped
            // the epoch, and `invalidate()` cleared the cached key — which would otherwise
            // *force* a fresh attestation here, registering a new key with the gateway for
            // an install that just opted out.
            try requireEpoch(epoch)

            return createAttestAndRegisterWrapper(
                clientId: clientId,
                epoch: epoch,
                existingKeyId: row?.keyId
            )
        }

        wrapper.addDependency(operations: [fetchOperation])

        return wrapper.insertingHead(operations: [fetchOperation])
    }

    /// challenge → attest → save unattested → register → save attested → cache, with an
    /// epoch gate before every step that is irreversible from the user's point of view.
    /// Each stage is its own function so those gates stay visible.
    func createAttestAndRegisterWrapper(
        clientId: String,
        epoch: Int,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        let challengeWrapper = remoteFactory.createChallengeWrapper()

        let attestationWrapper = createAttestationWrapper(
            clientId: clientId,
            epoch: epoch,
            existingKeyId: existingKeyId,
            challengeWrapper: challengeWrapper
        )

        attestationWrapper.addDependency(wrapper: challengeWrapper)

        // Saved unattested BEFORE the register POST, so a retry after a failed register
        // reuses the same attested key instead of burning a new one.
        let saveUnattestedOperation = createSaveOperation(isAttested: false, epoch: epoch) {
            try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
        }

        saveUnattestedOperation.addDependency(attestationWrapper.targetOperation)

        let registerOperation = createRegisterOperation(
            clientId: clientId,
            epoch: epoch,
            challengeWrapper: challengeWrapper,
            attestationWrapper: attestationWrapper,
            saveOperation: saveUnattestedOperation
        )

        registerOperation.addDependency(saveUnattestedOperation)

        let saveAttestedOperation = createSaveOperation(isAttested: true, epoch: epoch) {
            try registerOperation.extractNoCancellableResultData()

            return try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
        }

        saveAttestedOperation.addDependency(registerOperation)

        let mapOperation = createCacheOperation(
            epoch: epoch,
            attestationWrapper: attestationWrapper,
            saveOperation: saveAttestedOperation
        )

        mapOperation.addDependency(saveAttestedOperation)

        let dependencies = challengeWrapper.allOperations + attestationWrapper.allOperations +
            [saveUnattestedOperation, registerOperation, saveAttestedOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createAttestationWrapper(
        clientId: String,
        epoch: Int,
        existingKeyId: AppAttestKeyId?,
        challengeWrapper: CompoundOperationWrapper<String>
    ) -> CompoundOperationWrapper<AppAttestAttestation> {
        OperationCombiningService<AppAttestAttestation>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self, appAttest] in
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(epoch)

            return appAttest.createAttestationWrapper(using: existingKeyId) { keyId in
                AttestationClientData.attestationClientData(
                    challenge: challenge,
                    clientId: clientId,
                    keyId: keyId
                )
            }
        }
    }

    func createRegisterOperation(
        clientId: String,
        epoch: Int,
        challengeWrapper: CompoundOperationWrapper<String>,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
        saveOperation: BaseOperation<Void>
    ) -> BaseOperation<Void> {
        let appPackage = bundle.bundleIdentifier ?? ""

        return remoteFactory.createRegisterOperation { [weak self] in
            try saveOperation.extractNoCancellableResultData()

            // The last gate before the registration leaves the device. The Apple attestKey
            // round trip sits between here and the composition-time check, and it is the
            // slowest hop in the chain.
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            try requireEpoch(epoch)

            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()
            let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            return BackendAttestationRegisterRequest(
                clientId: clientId,
                platform: Constants.platform,
                appPackage: appPackage,
                attestationType: Constants.attestationType,
                keyId: attestation.keyId,
                challenge: challenge,
                integrityToken: attestation.attestation.base64EncodedString()
            )
        }
    }

    func createCacheOperation(
        epoch: Int,
        attestationWrapper: CompoundOperationWrapper<AppAttestAttestation>,
        saveOperation: BaseOperation<Void>
    ) -> BaseOperation<AppAttestKeyId> {
        ClosureOperation<AppAttestKeyId> { [weak self] in
            try saveOperation.extractNoCancellableResultData()

            let keyId = try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            // `cacheAttestedKeyId` also clears `needsFreshKey`, so caching here after an
            // opt-out would let a key minted for the old client sign for the new one.
            try requireEpoch(epoch)

            cacheAttestedKeyId(keyId)

            return keyId
        }
    }

    func createSaveOperation(
        isAttested: Bool,
        epoch: Int,
        keyIdClosure: @escaping () throws -> AppAttestKeyId
    ) -> BaseOperation<Void> {
        let identifier = rowIdentifier

        return repository.saveOperation({ [weak self] in
            let keyId = try keyIdClosure()

            // Never write the row back for an install that opted out while this chain ran:
            // `forgetClient()` deletes it, and a late save would resurrect it.
            guard let self else {
                return []
            }

            try requireEpoch(epoch)

            return [
                AppAttestKeySettings(
                    identifier: identifier,
                    keyId: keyId,
                    isAttested: isAttested
                )
            ]
        }, { [] })
    }
}

// MARK: - BackendAttestationProviderProtocol

extension BackendAttestationProvider: BackendAttestationProviderProtocol {
    func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        // Deferred so the state checks read the state as it is when the request runs,
        // not as it was when the flush was composed.
        let wrapper = OperationCombiningService<[AttestationHeaderKey: String]?>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [weak self] in
            guard let self else {
                throw BackendAttestationError.unsupported
            }

            return createHeadersWrapper(bodyClosure: bodyClosure)
        }

        let resultOperation = ClosureOperation<[AttestationHeaderKey: String]?> { [weak self] in
            do {
                return try wrapper.targetOperation.extractNoCancellableResultData()
            } catch {
                self?.handleFailure(error)

                throw error
            }
        }

        resultOperation.addDependency(wrapper.targetOperation)

        return wrapper.insertingTail(operation: resultOperation)
    }

    func markUnattested() {
        invalidate()
        deleteRow()
    }

    func forgetClient() {
        invalidate()
        identity.forgetClientId()
        deleteRow()
    }

    func allowClient() {
        identity.allowCreation()
    }
}
