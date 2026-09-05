import Foundation
import Operation_iOS
import NovaOperationSupport
import SDKLogger

/// Attests one App Attest key per install, then signs each gateway request with an assertion.
public final class BackendAttestationProvider {
    private let appAttest: AppAttestServiceProtocol
    private let remoteFactory: BackendAttestationRemoteFactoryProtocol
    private let identity: BackendAttestationIdentityProtocol
    private let repository: AnyDataProviderRepository<AppAttestKeySettings>
    private let gatewayURL: URL
    private let mode: BackendAttestationMode
    private let bundle: Bundle
    private let operationQueue: OperationQueue
    private let logger: SDKLoggerProtocol

    private let mutex = NSLock()

    private var attestedKeyId: AppAttestKeyId?
    private var rejectedForProcess: Bool = false
    private var invalidKeyIdDiscardedThisLaunch: Bool = false

    private var needsFreshKey: Bool = false

    public init(
        appAttest: AppAttestServiceProtocol,
        remoteFactory: BackendAttestationRemoteFactoryProtocol,
        identity: BackendAttestationIdentityProtocol,
        repository: AnyDataProviderRepository<AppAttestKeySettings>,
        gatewayURL: URL,
        mode: BackendAttestationMode,
        bundle: Bundle = .main,
        operationQueue: OperationQueue,
        logger: SDKLoggerProtocol
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
        static let rejectedStatusCode = 403
    }

    func rowIdentifier(for clientId: String) -> String {
        gatewayURL.absoluteString + "|" + clientId
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

    func invalidate() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        attestedKeyId = nil
        needsFreshKey = true
    }

    func deleteRow() {
        let operation = repository.deleteAllOperation()

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
            by: { self.rowIdentifier(for: clientId) },
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

        let saveUnattestedOperation = createSaveOperation(
            isAttested: false,
            epoch: epoch,
            clientId: clientId
        ) {
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

        let saveAttestedOperation = createSaveOperation(
            isAttested: true,
            epoch: epoch,
            clientId: clientId
        ) {
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

            try requireEpoch(epoch)

            cacheAttestedKeyId(keyId)

            return keyId
        }
    }

    func createSaveOperation(
        isAttested: Bool,
        epoch: Int,
        clientId: String,
        keyIdClosure: @escaping () throws -> AppAttestKeyId
    ) -> BaseOperation<Void> {
        let identifier = rowIdentifier(for: clientId)

        return repository.saveOperation({ [weak self] in
            let keyId = try keyIdClosure()

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
    public func createSignedHeadersWrapper(
        bodyClosure: @escaping () throws -> Data
    ) -> CompoundOperationWrapper<[AttestationHeaderKey: String]?> {
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

    public func markUnattested() {
        invalidate()
        deleteRow()
    }

    public func forgetClient() {
        invalidate()
        identity.forgetClientId()
        deleteRow()
    }

    public func allowClient() {
        identity.allowCreation()
    }
}
