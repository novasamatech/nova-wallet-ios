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
    var rowIdentifier: String { gatewayURL.absoluteString }

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

        let clientId = identity.clientId()

        return createSignedChainWrapper(clientId: clientId, bodyClosure: bodyClosure)
    }

    func createSignedChainWrapper(
        clientId: String,
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
        let attestedWrapper = ensureAttestedWrapper(clientId: clientId)

        // A fresh challenge per signed request: never cached, never reused (spec §7.5).
        let challengeWrapper = OperationCombiningService<String>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [remoteFactory] in
            _ = try attestedWrapper.targetOperation.extractNoCancellableResultData()

            return remoteFactory.createChallengeWrapper()
        }

        challengeWrapper.addDependency(wrapper: attestedWrapper)

        let assertionWrapper = OperationCombiningService<AppAttestAssertion>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [appAttest] in
            let keyId = try attestedWrapper.targetOperation.extractNoCancellableResultData()
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

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

    func ensureAttestedWrapper(clientId: String) -> CompoundOperationWrapper<AppAttestKeyId> {
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

            let row = resolveRow(try fetchOperation.extractNoCancellableResultData())

            if let row, row.isAttested {
                cacheAttestedKeyId(row.keyId)

                return .createWithResult(row.keyId)
            }

            return createAttestAndRegisterWrapper(clientId: clientId, existingKeyId: row?.keyId)
        }

        wrapper.addDependency(operations: [fetchOperation])

        return wrapper.insertingHead(operations: [fetchOperation])
    }

    func createAttestAndRegisterWrapper(
        clientId: String,
        existingKeyId: AppAttestKeyId?
    ) -> CompoundOperationWrapper<AppAttestKeyId> {
        let challengeWrapper = remoteFactory.createChallengeWrapper()

        let attestationWrapper = OperationCombiningService<AppAttestAttestation>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [appAttest] in
            let challenge = try challengeWrapper.targetOperation.extractNoCancellableResultData()

            return appAttest.createAttestationWrapper(using: existingKeyId) { keyId in
                AttestationClientData.attestationClientData(
                    challenge: challenge,
                    clientId: clientId,
                    keyId: keyId
                )
            }
        }

        attestationWrapper.addDependency(wrapper: challengeWrapper)

        // Saved unattested BEFORE the register POST, so a retry after a failed register
        // reuses the same attested key instead of burning a new one.
        let saveUnattestedOperation = createSaveOperation(isAttested: false) {
            try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
        }

        saveUnattestedOperation.addDependency(attestationWrapper.targetOperation)

        let appPackage = bundle.bundleIdentifier ?? ""

        let registerOperation = remoteFactory.createRegisterOperation {
            try saveUnattestedOperation.extractNoCancellableResultData()

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

        registerOperation.addDependency(saveUnattestedOperation)

        let saveAttestedOperation = createSaveOperation(isAttested: true) {
            try registerOperation.extractNoCancellableResultData()

            return try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
        }

        saveAttestedOperation.addDependency(registerOperation)

        let mapOperation = ClosureOperation<AppAttestKeyId> { [weak self] in
            try saveAttestedOperation.extractNoCancellableResultData()

            let keyId = try attestationWrapper.targetOperation.extractNoCancellableResultData().keyId
            self?.cacheAttestedKeyId(keyId)

            return keyId
        }

        mapOperation.addDependency(saveAttestedOperation)

        let dependencies = challengeWrapper.allOperations + attestationWrapper.allOperations +
            [saveUnattestedOperation, registerOperation, saveAttestedOperation]

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    func createSaveOperation(
        isAttested: Bool,
        keyIdClosure: @escaping () throws -> AppAttestKeyId
    ) -> BaseOperation<Void> {
        let identifier = rowIdentifier

        return repository.saveOperation({
            let keyId = try keyIdClosure()

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
}
